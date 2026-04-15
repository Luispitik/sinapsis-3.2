#!/usr/bin/env python3
"""Sinapsis Observer v3 - Single-invocation Python script.
Appends one JSONL observation per tool use to homunculus/projects/{hash}/observations.jsonl
Scrubs secrets from input/output before writing.
Sets is_error=True when output contains error keywords (used by session-learner)."""

import json, sys, os, re, hashlib, stat
try:
    import fcntl
except ImportError:
    fcntl = None  # Windows: fallback to no-lock (single-user safe)
from datetime import datetime, timezone


def main():
    hook_phase = sys.argv[1] if len(sys.argv) > 1 else "post"

    raw = sys.stdin.read().strip()
    if not raw:
        return

    try:
        data = json.loads(raw)
    except Exception:
        return

    # Skip subagents
    if data.get("agent_id"):
        return

    config_dir = os.path.expanduser("~/.claude/homunculus")
    projects_dir = os.path.join(config_dir, "projects")

    if os.path.exists(os.path.join(config_dir, "disabled")):
        return

    entrypoint = os.environ.get("CLAUDE_CODE_ENTRYPOINT", "cli")
    if entrypoint not in ("cli", "sdk", "api", "claude-desktop", ""):
        return
    if os.environ.get("ECC_HOOK_PROFILE") == "minimal":
        return
    if os.environ.get("ECC_SKIP_OBSERVE") == "1":
        return

    # Detect project via git
    cwd = data.get("cwd", "")
    project_id = "global"
    project_name = "global"
    project_dir = config_dir

    if cwd and os.path.isdir(cwd):
        project_name = os.path.basename(cwd)
        import subprocess
        try:
            root = subprocess.check_output(
                ["git", "-C", cwd, "rev-parse", "--show-toplevel"],
                stderr=subprocess.DEVNULL, text=True
            ).strip()
            if root:
                project_name = os.path.basename(root)
                try:
                    remote = subprocess.check_output(
                        ["git", "-C", root, "remote", "get-url", "origin"],
                        stderr=subprocess.DEVNULL, text=True
                    ).strip()
                except Exception:
                    remote = ""
                hash_input = remote or root
                project_id = hashlib.sha256(hash_input.encode()).hexdigest()[:12]
                project_dir = os.path.join(projects_dir, project_id)

                # Create project directory (archive dir created on demand)
                os.makedirs(project_dir, exist_ok=True)
        except Exception:
            pass

    # Parse hook event
    event = "tool_start" if hook_phase == "pre" else "tool_complete"
    tool_name = data.get("tool_name", data.get("tool", "unknown"))
    tool_input = data.get("tool_input", data.get("input", {}))
    tool_output = data.get("tool_response", data.get("tool_output", data.get("output", "")))
    session_id = data.get("session_id", "unknown")

    input_str = json.dumps(tool_input)[:5000] if isinstance(tool_input, dict) else str(tool_input)[:5000]
    output_str = json.dumps(tool_output)[:10000] if isinstance(tool_output, dict) else str(tool_output)[:10000]

    # Scrub secrets — 8 patterns (v4.3.3: added Stripe, Slack, SendGrid)
    SECRET_RE = re.compile(
        r"(?i)(api[_-]?key|token|secret|password|authorization|credentials?|auth)"
        r"([\"'\s:=]+)"
        r"([A-Za-z]+\s+)?"
        r"([A-Za-z0-9_\-/.+=]{8,})"
    )
    JWT_RE = re.compile(r"eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}")
    GITHUB_RE = re.compile(r"gh[ps]_[A-Za-z0-9]{36,}")
    AWS_RE = re.compile(r"AKIA[A-Z0-9]{16}")
    PEM_RE = re.compile(r"-----BEGIN [A-Z ]+-----[\s\S]*?-----END [A-Z ]+-----")
    # v4.3.3: 3 extra patterns (inspired by Cortex v3.10 — 12 patterns)
    STRIPE_RE = re.compile(r"(?:sk_live|sk_test|rk_live|rk_test)_[A-Za-z0-9]{20,}")
    SLACK_RE = re.compile(r"xox[bpras]-[A-Za-z0-9\-]{10,}")
    SENDGRID_RE = re.compile(r"SG\.[A-Za-z0-9_\-]{20,}\.[A-Za-z0-9_\-]{20,}")

    def scrub(val):
        if val is None:
            return None
        s = str(val)
        s = SECRET_RE.sub(
            lambda m: m.group(1) + m.group(2) + (m.group(3) or "") + "[REDACTED]",
            s
        )
        s = JWT_RE.sub("[JWT_REDACTED]", s)
        s = GITHUB_RE.sub("[GITHUB_TOKEN_REDACTED]", s)
        s = AWS_RE.sub("[AWS_KEY_REDACTED]", s)
        s = PEM_RE.sub("[PEM_REDACTED]", s)
        s = STRIPE_RE.sub("[STRIPE_KEY_REDACTED]", s)
        s = SLACK_RE.sub("[SLACK_TOKEN_REDACTED]", s)
        s = SENDGRID_RE.sub("[SENDGRID_KEY_REDACTED]", s)
        return s

    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    observation = {
        "timestamp": now,
        "event": event,
        "tool": tool_name,
        "session": session_id,
        "project_id": project_id,
        "project_name": project_name,
        "cwd": cwd,
    }

    if event == "tool_start":
        observation["input"] = scrub(input_str)
        # Extract file_path for Edit/Write (used by session-learner for correction detection)
        if tool_name in ("Edit", "Write") and isinstance(tool_input, dict):
            fp = tool_input.get("file_path", "")
            if fp:
                observation["file_path"] = fp

    if event == "tool_complete" and tool_output is not None:
        observation["output"] = scrub(output_str)
        # Also capture input for tool_complete (enables full context analysis)
        observation["input"] = scrub(input_str)
        # Flag errors — session-learner uses this to detect error→resolution patterns
        # Use word boundaries to avoid false positives like "0 errors found"
        error_patterns = [
            r"\berror[:\s]", r"\bfailed\b", r"\bexception\b",
            r"\btraceback\b", r"\berrno\b", r"\bEPERM\b", r"\bENOENT\b",
            r"exit code [1-9]", r"command not found",
        ]
        output_lower = output_str.lower()
        if any(re.search(pat, output_lower) for pat in error_patterns):
            observation["is_error"] = True
            # Extract first error line for downstream analysis
            for line in output_str.split('\n'):
                line_lower = line.strip().lower()
                if any(re.search(pat, line_lower) for pat in error_patterns):
                    observation["err_msg"] = scrub(line.strip()[:500])
                    break

    obs_file = os.path.join(project_dir, "observations.jsonl")

    # Auto-archive if file exceeds 10MB (with lock to prevent concurrent rotation)
    if os.path.exists(obs_file):
        try:
            if os.path.getsize(obs_file) >= 10 * 1024 * 1024:
                lock_path = obs_file + ".lock"
                try:
                    lock_fd = open(lock_path, "w")
                    if fcntl:
                        fcntl.flock(lock_fd.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
                    if os.path.exists(obs_file) and os.path.getsize(obs_file) >= 10 * 1024 * 1024:
                        archive_dir = os.path.join(project_dir, "observations.archive")
                        os.makedirs(archive_dir, exist_ok=True)
                        archive_name = "observations-" + datetime.now().strftime("%Y%m%d-%H%M%S") + ".jsonl"
                        os.rename(obs_file, os.path.join(archive_dir, archive_name))
                    if fcntl:
                        fcntl.flock(lock_fd.fileno(), fcntl.LOCK_UN)
                    lock_fd.close()
                except (IOError, OSError):
                    pass
        except Exception:
            pass

    try:
        with open(obs_file, "a", encoding="utf-8") as f:
            if fcntl:
                fcntl.flock(f.fileno(), fcntl.LOCK_EX)
            f.write(json.dumps(observation) + "\n")
            if fcntl:
                fcntl.flock(f.fileno(), fcntl.LOCK_UN)
        # v4.3.1: restrictive permissions on data files (#5D)
        try:
            os.chmod(obs_file, stat.S_IRUSR | stat.S_IWUSR)
        except Exception:
            pass
    except Exception:
        pass


if __name__ == "__main__":
    main()
