# Sinapsis Learning v4.1

> Continuous learning engine for Claude Code. Observes sessions via deterministic hooks,
> detects error patterns at session end, and injects learned instincts into future sessions.
> This skill is ALWAYS ACTIVE — it loads at session start.

---

## How It Actually Works

Sinapsis Learning is built on 4 deterministic bash hooks (no LLM in the pipeline):

```
PreToolUse  → observe.sh pre   (async) — logs tool + input to observations.jsonl
PostToolUse → observe.sh post  (async) — logs tool output + is_error flag
PreToolUse  → _project-context.sh (sync, once/session) — injects last context.md
PreToolUse  → _instinct-activator.sh (sync) — injects matched instincts
Stop        → _session-learner.sh — writes context.md + detects error patterns
On-demand   → _dream.sh — 5-module index hygiene (duplicates, contradictions, staleness, triggers, health)
```

**What fires automatically:** passive rules, instinct injection, observation logging, context.md writing.
**What requires your input:** reviewing proposals (`/analyze-session`), accepting new instincts, running `/evolve`.

---

## The Learning Pipeline

```
You work on a project
        |
        v
observe.sh logs every tool use → observations.jsonl
        |
        v
Session ends (Stop hook)
        |
    _session-learner.sh runs:
        ├── Writes context.md (project name, date, files touched, gotcha count)
        └── Detects error→fix patterns → _instinct-proposals.json (draft)
        |
        v
Next session starts
        |
    _project-context.sh injects context.md (once)
        |
        v
You run /analyze-session
        |
    Review proposals → accept/reject
        |
        v
Accepted instincts → _instincts-index.json (confirmed)
        |
        v
Future sessions:
    _instinct-activator.sh matches instincts → injects as systemMessage
```

---

## Instinct Levels

| Level | Behavior | How to reach |
|-------|----------|--------------|
| `draft` | Proposed, never injected. Visible in `/analyze-session` only. | session-learner detection |
| `confirmed` | Injected silently when trigger matches. | User accepts in `/analyze-session` |
| `permanent` | Highest priority in domain dedup. | User runs `/promote` |

**Domain dedup**: one instinct per domain fires per tool use. `permanent` beats `confirmed`. Max 3 domains total.

---

## Instinct Format

```json
{
  "id": "unique-id",
  "domain": "security|git|code-quality|deployment|testing|workflow|...",
  "level": "confirmed",
  "trigger_pattern": "regex matched against tool_name + tool_input",
  "inject": "The message injected as systemMessage when trigger matches.",
  "origin": "manual | learned",
  "added": "2026-01-15"
}
```

---

## What Gets Observed

Every tool use is logged to `~/.claude/homunculus/projects/{hash}/observations.jsonl`:

- Tool name and key input fields (file_path, command, pattern)
- Output excerpt (scrubbed of secrets)
- `is_error: true` flag when output contains error keywords (error, failed, exception, traceback)
- Timestamp and session ID

Observations stay **local** — no external transmission, no cloud sync.

---

## Active Capture (On Request)

You can also create instincts manually:
- "Learn this pattern" — Claude creates an instinct immediately (level: confirmed)
- "Never do X again" — anti-pattern instinct
- "Always use Y for Z" — preference instinct

Use `/instinct-status` to see all instincts and their levels.

---

## Integration with /evolve

When instincts cluster around a theme, `/evolve` lets you promote them:

- **[S]kill**: Create a reusable skill from a cluster of instincts
- **[C]ommand**: Create a slash command for a repeated workflow
- **[A]gent**: Create an autonomous agent for complex patterns
- **[R]ule**: Convert to a passive rule (fires on trigger, no instinct index needed)
- **[E]nrich**: Add knowledge to an existing skill
- **[P]romote**: Move from project scope to global scope
- **[X]**: Skip — not ready yet

---

## Privacy

- All data is local (`~/.claude/homunculus/`)
- No personal data captured in instincts — only patterns
- Delete any instinct: remove from `_instincts-index.json`
- Delete observations: remove the project's `observations.jsonl`
- `/instinct-status` shows everything that has been learned

---

## Commands

| Command | What it does |
|---------|-------------|
| `/analyze-session` | Review proposals from session-learner, accept/reject |
| `/instinct-status` | All instincts with levels and domains |
| `/evolve` | Promote mature instincts to skills/commands/rules |
| `/promote` | Move instinct from project scope to global |
| `/passive-status` | Which passive rules fire most, which never triggered |
| `/dream` | Run dream cycle: 5-module index hygiene with merge/archive actions |
