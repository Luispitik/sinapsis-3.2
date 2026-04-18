# /promote -- Promote Instincts

> Promote confirmed instincts to permanent level, giving them
> highest priority in domain dedup. Permanent instincts always
> win over confirmed ones in the same domain.

---

## Trigger

Run with `/promote` or "promote instinct".

---

## Requirements

- Instinct must have level `confirmed` (drafts cannot be promoted directly)
- Instinct must be in `_instincts-index.json`
- User validates the promotion

---

## Process

### Step 1: Show Eligible Instincts

```
PROMOTE TO PERMANENT

  Eligible instincts (confirmed level):

  #  ID                       Domain        Trigger Pattern
  1. git-commit-conventional  git           git commit|commit message
     → "Use conventional commits: feat/fix/chore/docs/..."

  2. error-handling-explicit  code-quality  try|catch|error|exception
     → "Handle errors explicitly. No silent catches."

  3. api-auth-check           security      route\.ts|api/
     → "API routes must validate authentication."

  Already permanent (cannot promote further):
  - env-vars-never-hardcode [security]

  Select instincts to promote:
  Enter numbers (e.g., "1 3"), [A] All eligible, [X] Cancel
```

### Step 2: Confirm

```
  Promoting 2 instincts to permanent:

  1. git-commit-conventional → permanent (wins over any confirmed git instinct)
  2. api-auth-check → permanent (wins over any confirmed security instinct)

  Permanent instincts have highest priority in domain dedup.
  [Y] Confirm  [N] Cancel
```

### Step 3: Execute

1. Update `level` from `confirmed` to `permanent` in `_instincts-index.json`
2. Preserve all other fields (trigger_pattern, inject, domain, origin, added)

### Step 4: Offer Law Distillation (v4.5+)

For each freshly promoted instinct, ask whether to distill a `Law` — a one-liner projection injected at SessionStart via `_laws-injector.sh`. Laws are cheaper than instincts (no regex match, always injected) and best suited for universal principles the user never wants to forget.

```
  git-commit-conventional is now permanent.
  Distill as Law? (always injected at SessionStart, ~300 token budget)

  Suggested: "Use conventional commits (feat/fix/chore/docs/refactor). Subject <=72 chars."
  Edit? [Enter to accept, type replacement, or [S] skip]
```

On accept, write to `~/.claude/skills/_laws/<instinct_id>.txt`:

```
---
id: <instinct_id>
source_instinct: <instinct_id>
source: /promote
created: <today>
last_injected: 1970-01-01T00:00:00Z
---
<one-liner text, <=40 tokens>
```

Heuristic for suggested text: take `instinct.inject`, trim to one clause, keep <=40 tokens. If user types replacement, use verbatim.

### Step 5: Summary

```
PROMOTION COMPLETE

  2 instincts promoted to permanent.
  1 distilled as Law.
  Permanent: 1 → 3
  Confirmed: 3 → 1
  Laws: 5 → 6

  These instincts now have highest priority in domain dedup.
```
