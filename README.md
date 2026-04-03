# Sinapsis v4.1

### The skill system for Claude Code that learns and adapts to you.

> Stop explaining the same thing twice. Sinapsis remembers, learns, and gets better with every session.

---

## What is Sinapsis?

Sinapsis is an intelligent skill management system for [Claude Code](https://claude.ai/code). It solves a fundamental problem: **Claude Code forgets everything between sessions.**

Every time you start a new session, Claude starts from zero. Your preferences, your tech stack, your workflows, your past decisions — all gone. You end up repeating yourself. Again. And again.

**Sinapsis fixes this.** It gives Claude Code:

- **Memory that persists** across sessions and projects
- **Skills that load on demand** instead of all at once
- **A learning engine** that observes what you do and creates reusable patterns
- **A router** that knows which tools you need for each project

Think of it as going from a dumb terminal to an assistant that actually knows you.

---

## What's New in v4.1

| Feature | Description |
|---------|-------------|
| **Closed learning pipeline** | observe → session-learner → proposals → /analyze-session → inject. All connected. |
| **Project context bridge** | `context.md` written at session end, injected at next session start. Never lose thread. |
| **Domain deduplication** | One instinct per domain per tool use. No contradictions. Max 3. |
| **3-level confidence** | `draft` / `confirmed` / `permanent`. No more decimal scoring noise. |
| **Honest observation model** | Hooks are deterministic scripts. No fake "real-time passive analysis." |
| **Token efficiency** | 2 global skills always active (was 5). Injected content is only what matches (~50–200 tokens). |

See [CHANGELOG.md](CHANGELOG.md) for full details.

---

## The Problem (Before Sinapsis)

| Issue | Impact |
|-------|--------|
| All skills loaded every session | ~25,000 tokens wasted before you say a word |
| No memory between sessions | You explain your stack, preferences, and context every time |
| No memory between projects | Decisions in project A don't carry to project B |
| No skill management | 50+ skills compete for attention, most irrelevant |
| No learning | Claude doesn't improve from session to session |

**In short: you do the same work over and over, and Claude never gets smarter.**

---

## The Solution (With Sinapsis)

| Feature | How it works |
|---------|-------------|
| **Skills on Demand** | Only loads the skills your current project needs (~2,800 tokens vs ~25,000) |
| **Operator State** | Your identity, stack, and decisions persist across ALL projects |
| **Sinapsis Engine** | 4 deterministic hooks: observe, inject, learn, bridge |
| **Skill Router** | Matches your intent to the right skills from a dormant catalog |
| **Passive Rules** | Technical guardrails that fire automatically (security, quality, workflow) |
| **Instinct Injection** | Learned patterns injected silently when context matches |
| **Project Cloning** | Clone a successful project as the base for a new one |

**Result: 90% less token waste. Zero repetition. Claude that actually improves.**

---

## Quick Start

### Requirements
- [Claude Code](https://claude.ai/code) installed
- [Node.js](https://nodejs.org) v18+ (required — injection hooks use it)
- [Python 3](https://python.org) (recommended — required for the observation pipeline that feeds the learning system; without it, passive rules and instinct injection still work, but Claude won't learn from your sessions)
- Git
- Git Bash (Windows only — needed to run `.sh` hook scripts)

### Fresh Installation

**macOS / Linux:**
```bash
git clone https://github.com/Luispitik/sinapsis-3.2.git
cd sinapsis-3.2
chmod +x install.sh
./install.sh
```

**Windows (Command Prompt):**
```cmd
git clone https://github.com/Luispitik/sinapsis-3.2.git
cd sinapsis-3.2
install.bat
```

> **Windows note:** The `.sh` hook scripts run via Git Bash or WSL. If you use Claude Code on Windows, make sure Git Bash is installed and Claude Code can access it. The installer will remind you of this.

After install, open Claude Code in any project folder. Sinapsis guides you through first-time setup.

---

## Upgrading from v3.2

If you already have v3.2 installed, the installer handles the upgrade automatically — it backs up your existing installation first and preserves your `operator-state.json` and `CLAUDE.md`.

```bash
# Pull the latest changes
git -C sinapsis-3.2 pull origin main

# Run the installer again — it detects the upgrade automatically
cd sinapsis-3.2
./install.sh        # macOS / Linux
# install.bat       # Windows
```

**What the upgrade adds:**

| File | Where | What it does |
|------|-------|-------------|
| `_passive-activator.sh` | `~/.claude/skills/` | Fires matching passive rules per tool use |
| `_instinct-activator.sh` | `~/.claude/skills/` | Injects matched instincts per tool use |
| `_session-learner.sh` | `~/.claude/skills/` | Writes `context.md` + detects patterns at session end |
| `_project-context.sh` | `~/.claude/skills/` | Injects last-session context at session start (once) |
| `_instincts-index.json` | `~/.claude/skills/` | Instinct registry (starts with 3 generic examples) |

**If you prefer to upgrade manually:**

```bash
# 1. Pull the repo
git pull origin main

# 2. Copy the new scripts
cp core/_passive-activator.sh ~/.claude/skills/
cp core/_instinct-activator.sh ~/.claude/skills/
cp core/_session-learner.sh ~/.claude/skills/
cp core/_project-context.sh ~/.claude/skills/
chmod +x ~/.claude/skills/_passive-activator.sh
chmod +x ~/.claude/skills/_instinct-activator.sh
chmod +x ~/.claude/skills/_session-learner.sh
chmod +x ~/.claude/skills/_project-context.sh

# 3. Copy the new config files
cp core/_instincts-index.json ~/.claude/skills/
cp core/_passive-rules.json ~/.claude/skills/   # optional: review before overwriting

# 4. Add hooks to ~/.claude/settings.json
# See core/settings.template.json for the exact format
```

**Windows manual upgrade:**
```cmd
copy /Y core\_passive-activator.sh %USERPROFILE%\.claude\skills\
copy /Y core\_instinct-activator.sh %USERPROFILE%\.claude\skills\
copy /Y core\_session-learner.sh %USERPROFILE%\.claude\skills\
copy /Y core\_project-context.sh %USERPROFILE%\.claude\skills\
copy /Y core\_instincts-index.json %USERPROFILE%\.claude\skills\
```

**Then update `settings.json`** — see `core/settings.template.json` for the 6-hook configuration. If you already have hooks, merge them rather than overwriting.

---

## How It Works

### The Session Flow

```
Open Claude Code
       |
       v
  CLAUDE.md loads (entry point)
       |
       v
  Read Operator State
  (your identity + decisions)
       |
       v
  Check for EOD summary
  (auto-resume if exists)
       |
       v
  Launcher appears
  (skipped if resuming):
  [1] Skills on Demand
  [2] Skill Picker (manual)
  [3] Freestyle (vanilla)
       |
       v
  Install ONLY what you need
  (~2,800 tokens instead of ~25,000)
       |
       v
  You work normally
  Hooks observe silently (deterministic)
       |
       v
  Run /eod before closing
  (saves context for tomorrow)
```

### The Learning Pipeline (v4.1)

```
  You work on your project
         |
         v
  observe.sh logs every tool use
  → observations.jsonl (local only)
         |
         v
  Session ends (Stop hook)
         |
    session-learner runs:
    ├── Writes context.md per project
    └── Detects error→fix patterns
        → _instinct-proposals.json
         |
         v
  Next session:
  context.md injected (once, first tool use)
         |
         v
  You run /analyze-session
  → Review proposals → Accept
  → _instincts-index.json (confirmed)
         |
         v
  Future sessions:
  _instinct-activator.sh matches
  instincts → injects as context
         |
         v
  Pattern matures? Run /evolve
  → Create Skill, Command, Rule...
         |
         v
  Cycle repeats.
  Every session feeds the next.
```

---

## The Hook Architecture (v4.1)

Sinapsis uses 6 deterministic hooks configured in `settings.json`:

| Hook | Event | Type | Purpose |
|------|-------|------|---------|
| `observe.sh pre` | PreToolUse | async | Log tool name + input |
| `_project-context.sh` | PreToolUse | sync (3s) | Inject last session context (once/session) |
| `_passive-activator.sh` | PreToolUse | sync (5s) | Fire matching passive rules |
| `_instinct-activator.sh` | PreToolUse | sync (5s) | Inject matched instincts |
| `observe.sh post` | PostToolUse | async | Log tool output + is_error flag |
| `_session-learner.sh` | Stop | sync (15s) | Write context.md + detect error patterns |

See `core/settings.template.json` for the exact configuration.

---

## Token Budget

| Component | Tokens | When |
|-----------|--------|------|
| 2 global skills (router + learning) | ~2,800 | Every session |
| Passive rules (matched only) | ~20–80 | Per matching tool use |
| Instincts (matched only) | ~50–200 | Per matching tool use |
| Project context bridge | ~50–150 | Once per session |
| **Total session start** | **~2,800–3,200** | vs ~25,000 before |

---

## Commands

| Command | What it does |
|---------|-------------|
| `/system-status` | Full dashboard: skills, tokens, projects, health |
| `/evolve` | Analyze mature instincts, create skills/rules/commands |
| `/analyze-session` | Review proposals from session-learner, accept/reject |
| `/clone` | Clone a project as base for a new one |
| `/passive-status` | Which passive rules fire, which never triggered |
| `/instinct-status` | All learned patterns with levels |
| `/promote` | Move instinct from project scope to global |
| `/projects` | List all known projects with stats |
| `/eod` | Save work context for tomorrow's session |

### Session Continuity (`/eod`)

Never lose context between sessions. Run `/eod` before closing Claude:

1. Sinapsis captures your git activity, open PRs, and learning progress
2. You add priorities and notes for tomorrow
3. Next morning, Claude greets you with a summary and asks where to start

No more "what was I doing yesterday?" — Sinapsis remembers for you.

Use `/eod --quick` for a fast auto-generated summary, or `/eod --yesterday` to review your last saved session.

---

## Architecture

```
~/.claude/
  CLAUDE.md                    <-- Entry point (loaded every session)
  skills/
    skill-router/              <-- Orchestrator (always active)
    sinapsis-learning/         <-- Learning engine (always active)
    _library/                  <-- Dormant skills (installed on demand)
    _archived/                 <-- Retired skills (recoverable)
    _daily-summaries/          <-- EOD session summaries (auto-resume)
    _catalog.json              <-- Skill registry with token estimates
    _passive-rules.json        <-- Automatic guardrails
    _passive-activator.sh      <-- Hook: fires matching passive rules
    _instinct-activator.sh     <-- Hook: injects matched instincts
    _instincts-index.json      <-- Instinct registry
    _instinct-proposals.json   <-- Draft proposals from session-learner
    _project-context.sh        <-- Hook: injects project context (once/session)
    _session-learner.sh        <-- Stop hook: writes context + detects patterns
    _operator-state.json       <-- Your identity + decisions (cross-project)
    _projects.json             <-- Project registry
  commands/                    <-- Slash commands (/evolve, /clone, etc.)
  homunculus/
    projects/{hash}/
      observations.jsonl       <-- Raw tool observations (local only)
      context.md               <-- Last session summary (14-day TTL)
```

---

## FAQ

**Does this work with any Claude Code project?**
Yes. Sinapsis is project-agnostic. It adapts to whatever you're building.

**Will it slow down Claude?**
No. Async hooks don't block responses. By reducing token overhead by ~90%, Claude has more context for actual work.

**Can I use it without the learning system?**
Yes. Choose [3] Freestyle in the launcher for vanilla Claude Code.

**Can I create my own instincts?**
Yes. Edit `_instincts-index.json` directly, or use `/evolve`, or tell Claude "learn this pattern."

**Can I create my own passive rules?**
Yes. Use `/evolve → [R]` or edit `_passive-rules.json` directly.

**Does it work on Windows, Mac, and Linux?**
Yes. Installers for all three platforms included.

**Is my data sent anywhere?**
No. All observations, instincts, and context files stay in `~/.claude/homunculus/` on your machine.

---

## Want More?

Sinapsis is the open-source foundation. If you want:

- **Custom skills** for your business or industry
- **Mentoring** on how to build and optimize your own skill system
- **Advanced features** like marketplace integration and team sharing
- **Training** for your team on Claude Code + Sinapsis

Visit **[salgadoia.com](https://salgadoia.com)** for mentoring, courses, and consulting.

---

## License

Sinapsis is **source-available** under a custom license:

- **Free** for personal and internal business use
- **Free** to study, modify, and learn from
- **Commercial exploitation** exclusively reserved to Luis Salgado / SalgadoIA

See [LICENSE](LICENSE) for full terms.

---

## Credits

Built by [Luis Salgado](https://salgadoia.com) — AI consultant, developer, and educator.

Powered by [Claude Code](https://claude.ai/code) by Anthropic.

---

*Sinapsis: because your AI assistant should remember who you are.*
