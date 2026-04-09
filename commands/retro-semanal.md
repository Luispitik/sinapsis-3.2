---
name: retro-semanal
description: Retrospectiva semanal con metricas de commits, skills, instincts y health score
command: true
---

# /retro-semanal

> Weekly retrospective with metrics across all projects.
> Inspired by garrytan/gstack `/retro`.

## Trigger

Run with `/retro-semanal`, "retro", "retrospectiva", "que hicimos esta semana".

**Flags:**
- `/retro-semanal` — Current week (Monday to today)
- `/retro-semanal --last` — Previous week
- `/retro-semanal --from 2026-04-01 --to 2026-04-07` — Custom range

---

## Process

### Step 1: Determine Date Range

Default: Monday of current week to today.
With `--last`: Monday to Sunday of previous week.
With `--from/--to`: custom range.

```bash
# Get Monday of current week
WEEK_START=$(date -d "last monday" +%Y-%m-%d 2>/dev/null || date -v-monday +%Y-%m-%d)
TODAY=$(date +%Y-%m-%d)
```

### Step 2: Gather Git Metrics Per Project

Read `~/.claude/skills/_projects.json` for all active projects with `root` paths.

For each project with a valid git root:

```bash
cd "{project_root}"
git log --oneline --since="{WEEK_START}" --until="{TODAY} 23:59" --format="%h %s" 2>/dev/null
git log --since="{WEEK_START}" --until="{TODAY} 23:59" --shortstat 2>/dev/null
git branch --show-current 2>/dev/null
```

Collect: commit count, files changed, insertions, deletions, current branch.

### Step 3: Gather Skill Usage (Session Timeline)

Read `~/.claude/skills/_session-timeline.jsonl`.
Filter entries where `ts` falls within the date range.
Count skill invocations grouped by skill name.

If `_session-timeline.jsonl` does not exist or is empty, skip this section with note: "No session timeline data available. Skills will be tracked after first use."

### Step 4: Gather Instinct Metrics

Read `~/.claude/skills/_instincts-index.json`.

Count:
- Instincts with `last_triggered` within the date range (activated this week)
- Instincts with `first_triggered` within the date range (new this week)
- Instincts where level changed (promoted or demoted) — compare with previous week if `/retro-semanal --last` exists

Read `~/.claude/skills/_instinct-proposals.json` if it exists:
- Count proposals from this week

### Step 5: Calculate Health Score

Health score formula (0-10):
- Base: 5.0
- +1.0 if commits > 10 across all projects
- +0.5 if commits > 5
- +1.0 if instincts activated > 5
- +0.5 if new instincts discovered
- +1.0 if no decaying instincts (all active <60d)
- +0.5 if session timeline has entries (skills being tracked)
- +0.5 if all projects have CLAUDE.md
- -1.0 for each project with 0 activity and >14 days since last commit

Compare with previous retro if it exists (read `~/.claude/skills/_retro-history.jsonl`).

### Step 6: Generate Recommendations

Based on the data:
- Projects with 0 activity for >14 days: "Consider archiving or scheduling work"
- Passive rules with 0 activations in 30 days: "Evaluate if still relevant"
- Instincts decaying (confirmed >60d inactive): "Review or archive"
- Skills never used: "Consider removing from catalog"

### Step 7: Display Report

```markdown
══════════════════════════════════════════════════
  RETRO SEMANAL — Sinapsis
  Periodo: {WEEK_START} -> {TODAY}
══════════════════════════════════════════════════

COMMITS POR PROYECTO
| Proyecto           | Commits | Files | +Lines | -Lines | Branch        |
|--------------------|---------|-------|--------|--------|---------------|
| project-alpha      | 12      | 34    | 1,200  | 450    | feat/crm      |
| project-beta       | 8       | 22    | 800    | 200    | main          |
| ...                |         |       |        |        |               |
| TOTAL              | 20      | 56    | 2,000  | 650    |               |

SKILLS MAS USADAS (session timeline)
  1. /review-army            5 invocaciones
  2. /cso-audit              3 invocaciones
  3. /investigate-pro        2 invocaciones

INSTINCTS
  Activados esta semana:     {N}
  Nuevos descubiertos:       {N}
  Promovidos:                {N}
  Archivados por decay:      {N}
  Top activado: {instinct-id} ({N}x)

HEALTH SCORE
  Esta semana:    {score}/10
  Semana pasada:  {prev}/10 ({delta})

RECOMENDACIONES
  - {recommendation 1}
  - {recommendation 2}
  - {recommendation 3}

══════════════════════════════════════════════════
```

### Step 8: Save to History

Append a summary line to `~/.claude/skills/_retro-history.jsonl`:

```jsonl
{"week_start":"2026-04-07","week_end":"2026-04-09","projects":3,"commits":20,"instincts_activated":8,"health_score":7.5}
```

### Step 9: Offer Actions

After displaying the report, ask:
```
Actions available:
[1] Archive inactive projects
[2] Review decaying instincts
[3] Generate EOD from this data
[4] Done
```

---

## What NOT to Do

- Do not modify project code or files
- Do not invent metrics — only report from actual data
- Do not run tests, builds, or deployments
- Do not promote or demote instincts — this is read-only analysis
- Do not push any changes
