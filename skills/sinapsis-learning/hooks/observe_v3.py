#!/usr/bin/env python3
"""Sinapsis Observer v3 - Single-invocation Python script.
Appends one JSONL observation per tool use to homunculus/projects/{hash}/observations.jsonl
Scrubs secrets from input/output before writing.
Sets is_error=True when output contains error keywords (used by session-learner)."""

import json, sys, os, re, hashlib
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

                # Create directory structure
                for d in ["instincts/personal", "instincts/inherited",
                          "observations.archive", "evolved/skills",
                          "evolved/commands", "evolved/agents"]:
                    os.makedirs(os.path.join(project_dir, d), exist_ok=True)
        except Exception:
            pass

    # Parse hook event
    event = "tool_start" if hook_phase == "pre" else "tool_complete"
    tool_name = data.get("tool_name", data.get("tool", "unknown"))
    tool_input = data.get("tool_input", data.get("input", {}))
    tool_output = data.get("tool_response", data.get("tool_output", data.get("output", "")))
    session_id = data.get("session_id", "unknown")

    input_str = json.dumps(tool_input)[:5000] if isinstance(tool_input, dict) else str(tool_input)[:5000]
    output_str = json.dumps(tool_output)[:5000] if isinstance(tool_output, dict) else str(tool_output)[:5000]

    # Scrub secrets
    SECRET_RE = re.compile(
        r"(?i)(api[_-]?key|token|secret|password|authorization|credentials?|auth)"
        r"([\"'\s:=]+)"
        r"([A-Za-z]+\s+)?"
        r"([A-Za-z0-9_\-/.+=]{8,})"
    )

    def scrub(val):
        if val is None:
            return None
        return SECRET_RE.sub(
            lambda m: m.group(1) + m.group(2) + (m.group(3) or "") + "[REDACTED]",
            str(val)
        )

    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    observation = {
        "timestamp": now,
        "event": event,
        "tool": tool_name,
        "session": session_id,
        "project_id": project_id,
        "project_name": project_name,
    }

    if event == "tool_start":
        observation["input"] = scrub(input_str)

    if event == "tool_complete" and tool_output is not None:
        observation["output"] = scrub(output_str)
        # Flag errors — session-learner uses this to detect error→resolution patterns
        error_keywords = ["error", "failed", "exception", "traceback", "errno"]
        if any(kw in output_str.lower() for kw in error_keywords):
            observation["is_error"] = True

    obs_file = os.path.join(project_dir, "observations.jsonl")

    # Auto-archive if file exceeds 10MB
    if os.path.exists(obs_file):
        try:
            if os.path.getsize(obs_file) >= 10 * 1024 * 1024:
                archive_dir = os.path.join(project_dir, "observations.archive")
                os.makedirs(archive_dir, exist_ok=True)
                archive_name = "observations-" + datetime.now().strftime("%Y%m%d-%H%M%S") + ".jsonl"
                os.rename(obs_file, os.path.join(archive_dir, archive_name))
        except Exception:
            pass

    try:
        with open(obs_file, "a", encoding="utf-8") as f:
            f.write(json.dumps(observation) + "\n")
    except Exception:
        pass


if __name__ == "__main__":
    main()
