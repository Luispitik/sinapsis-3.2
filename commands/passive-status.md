# /passive-status -- Passive Rules Dashboard

> Show which passive rules are active, which fire most often,
> and which have never fired (candidates for removal).

---

## Trigger

Run with `/passive-status` or "show passive rules".

---

## Process

1. Read `~/.claude/skills/_passive-rules.json`
2. For each rule, check usage stats
3. Sort by fire count descending
4. Display dashboard

---

## Dashboard Format

```
PASSIVE RULES STATUS

  Active rules: 6
  Total fires this month: 127
  Token overhead: ~800 tokens/session

  MOST ACTIVE
  ───────────
  #  Rule                        Fires  Last Fired   Domain
  1. conventional-commits           47   today        workflow
  2. validate-env-before-deploy     28   2 days ago   deployment
  3. typescript-strict-mode         23   today        development
  4. add-timestamps-to-tables       18   1 week ago   development

  MODERATE
  ────────
  5. check-rls-on-supabase          11   2 weeks ago  security

  NEVER FIRED
  ───────────
  6. legacy-migration-warn           0   never        deployment
     Reason: Trigger condition may be too specific
     [R] Remove  [E] Edit trigger  [K] Keep

  SUMMARY
  ───────
  Avg fires/rule: 21.2
  Most valuable:  "conventional-commits" (47 fires, saves ~5 sec each)
  Least valuable: "legacy-migration-warn" (0 fires)

  Actions:
  [N] New rule  [E] Edit a rule  [R] Remove a rule  [X] Close
```

---

## Rule Format Reference

Each passive rule in `_passive-rules.json`:

```json
{
  "id": "env-never-commit",
  "trigger": "git add|git commit",
  "inject": "Verify .env* is in .gitignore. NEVER commit secrets or API keys.",
  "severity": "critical",
  "category": "security",
  "tokens": 20
}
```

Fields:
- `id`: Unique rule identifier
- `trigger`: Regex pattern matched against tool_name + tool_input (or "EVERY_SESSION" for always-fire)
- `inject`: Text injected into Claude's context when trigger matches
- `severity`: critical | high | medium
- `category`: security | workflow | quality | memory
- `tokens`: Approximate token cost of the inject text

Note: Fire count tracking is not yet implemented. The dashboard shows rule definitions and
estimates activity based on trigger breadth. Future: add `fireCount` and `lastFired` fields
via `_passive-activator.sh` atomic writes (same pattern as instinct occurrence tracking).
