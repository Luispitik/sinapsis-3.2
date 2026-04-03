# /instinct-status -- Instinct Dashboard

> Show all instincts grouped by level (permanent, confirmed, draft)
> with their domains, trigger patterns, and injection status.

---

## Trigger

Run with `/instinct-status` or "show my instincts".

---

## Process

1. Read `~/.claude/skills/_instincts-index.json`
2. Read `~/.claude/skills/_instinct-proposals.json` (if exists, for drafts)
3. Group by level: permanent → confirmed → draft
4. Display dashboard

---

## Dashboard Format

```
INSTINCT STATUS

  Active instincts: 5 (2 permanent + 3 confirmed)
  Pending proposals: 2 drafts (review with /analyze-session)
  Domain dedup: max 3 domains injected per tool use

  ============================================
  PERMANENT (always wins in domain dedup)
  ============================================

  ID                       Domain        Trigger Pattern
  env-vars-never-hardcode  security      api.?key|secret|password|...
    → "Never hardcode secrets. Use environment variables."

  ============================================
  CONFIRMED (injected when trigger matches)
  ============================================

  ID                       Domain        Trigger Pattern
  git-commit-conventional  git           git commit|commit message
    → "Use conventional commits: feat/fix/chore/docs/..."

  error-handling-explicit  code-quality  try|catch|error|exception
    → "Handle errors explicitly. No silent catches."

  api-auth-check           security      route\.ts|api/
    → "API routes must validate authentication."

  ============================================
  DRAFTS (not injected — review with /analyze-session)
  ============================================

  ID          Type              Evidence
  fix-edit    error_resolution  Edit error resolved — 2026-03-31
  fix-bash    error_resolution  Bash error resolved — 2026-03-31

  ============================================
  DOMAIN DEDUP RULES
  ============================================

  When multiple instincts match the same tool use:
  - One instinct per domain (permanent > confirmed)
  - Maximum 3 domains injected simultaneously
  - Drafts are NEVER auto-injected

  ============================================
  Actions:
  [A] /analyze-session  -- Review and confirm drafts
  [E] /evolve           -- Create new instincts or evolve to skills
  [P] /promote          -- Promote confirmed → permanent
  [D] Delete            -- Remove an instinct by ID
  [X] Close
```
