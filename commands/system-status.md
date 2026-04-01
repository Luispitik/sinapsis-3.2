# /system-status -- System Dashboard

> Complete overview of the Skills on Demand system state.
> Shows skills, tokens, operator state, instincts, and sync status.

---

## Trigger

Run with `/system-status` or "system status".

---

## Dashboard Format

```
======================================================
        SKILLS ON DEMAND -- SYSTEM STATUS
======================================================

  SKILLS                                        [GREEN]
  ──────
  Installed:    12 skills + 5 global
  In library:   24 available (3 new since last check)
  Archived:     8 retired skills
  Token cost:   ~12,200 tokens/session (6.1%)
  Outdated:     0

  COMMANDS                                      [GREEN]
  ────────
  Active:       7 slash commands
  Token cost:   ~2,800 tokens/session

  INSTINCTS                                     [GREEN]
  ─────────
  Global:       15 (3 laws, 8 instincts, 4 patterns)
  Project:      28 (current project)
  Pending:      4 ready for /evolve (confidence >= 0.7)
  Stale:        2 (no activity in 60+ days)

  OBSERVATIONS                                  [YELLOW]
  ────────────
  Total:        312 logged
  Active:       145 (< 30 days)
  Archivable:   167 (> 30 days, no linked instinct)
  Tip: Run /analyze-session to process

  PASSIVE RULES                                 [GREEN]
  ─────────────
  Active:       6 rules
  Most fired:   "conventional-commits" (47 times)
  Never fired:  "legacy-migration-warn" (consider removing)

  SESSION CONTINUITY                            [STATUS]
  ───────────────────
  Last EOD:       {date of most recent file in _daily-summaries/}
  Summaries:      {count of .md files in _daily-summaries/}
  Status:         GREEN if EOD today/yesterday, YELLOW if >2 days or none, RED if >7 days
  Tip: Run /eod before ending your session

  OPERATOR STATE                                [GREEN]
  ──────────────
  Last updated: 2 days ago
  Retired tech: 1 entry (n8n -- warn on use)
  Decisions:    6 strategic decisions logged
  Lessons:      3 cross-project lessons

  TOKEN BUDGET                                  [GREEN]
  ────────────
  Fixed overhead:     ~15,000 tokens
  Budget:             ~200,000 tokens
  Usage:              7.5%
  Remaining for work: ~185,000 tokens

  PROJECTS                                      [GREEN]
  ────────
  Known:        4 projects
  Active:       2 (activity in last 7 days)
  Blueprints:   1 available for cloning

  SYNC STATUS                                   [GREEN]
  ───────────
  GitHub repo:  connected
  Last sync:    1 day ago
  Pending:      0 changes to push

======================================================
  Overall: HEALTHY
  Recommendations:
  - Archive 167 stale observations
  - Evolve 4 mature instincts (/evolve)
  - Review "legacy-migration-warn" passive rule
======================================================
```

---

## Color Coding

| Status | Meaning |
|--------|---------|
| `[GREEN]` | Healthy, no action needed |
| `[YELLOW]` | Attention recommended but not urgent |
| `[ORANGE]` | Action recommended soon |
| `[RED]` | Immediate action needed |

### Thresholds

- **Skills**: RED if token overhead > 40%, ORANGE if > 25%, YELLOW if > 15%
- **Instincts**: YELLOW if > 5 stale, RED if conflicts detected
- **Observations**: YELLOW if > 300 total, RED if > 500
- **Passive Rules**: YELLOW if any never fired in 30+ days
- **Operator State**: RED if unreadable, YELLOW if > 7 days stale
- **Session Continuity**: GREEN if EOD saved today or yesterday, YELLOW if > 2 days or no summaries, RED if > 7 days
- **Sync**: RED if push failed, YELLOW if > 7 days since sync

---

## Quick Actions

After displaying the dashboard, offer:

```
Quick actions:
  [E] /evolve          -- Process mature instincts
  [A] /skill-audit     -- Deep skill analysis
  [O] /analyze-obs     -- Process observations
  [P] /passive-status  -- Passive rules detail
  [R] Refresh          -- Re-run this dashboard
```
