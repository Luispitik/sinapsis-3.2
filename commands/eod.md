# /eod -- End of Day Summary

> Save your work context for tomorrow. Next session, Claude greets you
> with what you did and what's next — no re-explaining needed.
> Never lose context between sessions again.

---

## Trigger

Run with `/eod`, "end of day", "save for tomorrow", "wrap up", or "guardar sesión".

**Flags:**
- `/eod --quick` — Auto-generate from git data only, skip user input
- `/eod --yesterday` — Show the most recent saved summary

---

## Process

### Step 1: Gather Context (automatic)

Scan the current project directory for today's activity:

```bash
# Today's commits (if git config user.email is empty, omit the --author filter)
AUTHOR=$(git config user.email 2>/dev/null)
if [ -n "$AUTHOR" ]; then
  git log --oneline --since="00:00" --author="$AUTHOR"
else
  git log --oneline --since="00:00"
fi

# Current branch
git branch --show-current 2>/dev/null

# Uncommitted changes
git status -s 2>/dev/null

# Open PRs (skip silently if gh CLI not available)
gh pr list --state open --author @me 2>/dev/null
```

Also gather Sinapsis learning state:
- Read `~/.claude/skills/_instincts-index.json` → count total instincts by level (draft/confirmed/permanent)
- Read `~/.claude/homunculus/projects/{hash}/observations.jsonl` → count entries from today

### Step 2: Ask for Priorities (unless --quick)

If `--quick` was NOT passed, ask the user:

```
What should we focus on tomorrow? Any priorities, blockers, or notes to carry over?
(Press Enter to skip — I'll generate priorities from git activity)
```

If user provides input: include it verbatim in "For tomorrow" section.
If user skips: auto-generate priorities from uncommitted files, open PRs, and recent commit patterns.

### Step 3: Generate Summary

Compose the summary in this exact format:

```markdown
# EOD — {YYYY-MM-DD}

## Project: {project-name}
Branch: {current-branch}

### What was done
- {Summary of each commit, grouped by theme}
- {Any notable changes not in commits}

### Pending
- {Uncommitted files, if any}
- {Open PRs with status}

### For tomorrow
- {Priority 1}
- {Priority 2}
- {Priority 3}

---

## Sinapsis Learning
- Instincts today: {count new or updated}
- Observations today: {count}

## Notes
- {User-provided carry-over notes}
- {Any important context detected from the session}

## Quick Resume
> "{1-2 sentence summary in the user's preferred language.
> Include: project name, what was accomplished, and top priority for tomorrow.
> This gets injected at the start of the next session.}"
```

### Step 4: Save to Disk

Write the summary to:
```
~/.claude/skills/_daily-summaries/{YYYY-MM-DD}.md
```

Create the `_daily-summaries` directory if it does not exist.

### Step 5: Display Confirmation

Show a compact visual summary:

```
======================================================
  EOD — {YYYY-MM-DD}
======================================================

  PROJECT: {name} ({branch})
  ──────────────────────────
  Commits today:    {N}
  Files changed:    {N}
  Pending files:    {N}
  Open PRs:         {N}

  FOR TOMORROW:
  1. {Priority 1}
  2. {Priority 2}
  3. {Priority 3}

  SYNAPIS: +{N} observations | +{N} instincts today

  Saved: ~/.claude/skills/_daily-summaries/{date}.md

  Tomorrow, I'll greet you with this summary automatically.
======================================================
```

---

## Edge Cases

- **No git in directory**: Skip git data. Ask user: "No git repo detected. Want to write a manual summary for tomorrow?"
- **No gh CLI**: Skip PR data silently, continue with everything else.
- **No activity today**: Show: "No commits or changes detected today. Want to save notes for tomorrow anyway?"
- **Already saved today**: Show: "EOD already saved for today. Overwrite with updated data? (y/n)"
- **Multiple projects**: If the user worked in multiple git repos today (detected from session context), include a section for each.
- **--yesterday flag**: List files with `ls -t ~/.claude/skills/_daily-summaries/*.md 2>/dev/null | head -1` to find the most recent summary, then Read that file. If no files exist, show: "No EOD summaries saved yet. Run /eod to create your first one."

---

## How Resume Works (next session)

The Skill Router reads yesterday's summary at session start (see `skill-router/SKILL.md` → "Check for Yesterday's Summary").

When a Quick Resume exists, Claude's first response follows this pattern:

```
Welcome back! Here's where we left off:

{Paraphrased Quick Resume — what was done yesterday}

Priorities for today:
1. {From "For tomorrow" section}
2. {From "For tomorrow" section}

Where do you want to start?
```

The launcher menu is skipped when a resume exists — the user goes straight to work.
They can say "launcher" anytime to access the menu.

---

## What NOT to Do

- Do not invent activity that did not happen — use git data and user input only
- Do not modify any project files or code
- Do not run tests, builds, or any side-effect commands
- Do not overwrite an existing summary without asking
- Do not include sensitive data (env vars, tokens, passwords) in the summary
