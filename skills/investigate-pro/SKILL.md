---
name: investigate-pro
version: 1.0.0
description: |
  Systematic 4-phase debugging: investigate, analyze, hypothesize, implement.
  Iron Law: no fix without confirmed root cause. Scope freeze prevents scope creep.
  Integrates with Sinapsis to search for previously resolved patterns.
  Inspired by gstack /investigate (garrytan).
tags: [debugging, investigation, root-cause, bug-fix, diagnostics]
triggers: ["debug", "investigate", "root cause", "fix this bug", "why is this failing", "diagnose"]
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Agent
  - Edit
  - Write
  - TodoWrite
---

# /investigate-pro — Systematic Debugging in 4 Phases

> Iron Law: NO FIX without confirmed root cause.
> Scope freeze: only touch files related to the bug.

---

## When to Use

- User reports a bug, error, or unexpected behavior
- Something broke after a deploy or merge
- A test is failing and the cause is unclear
- Performance degradation needs investigation

## When NOT to Use

- Simple typo or obvious fix (just fix it directly)
- Feature requests (use normal development flow)
- Security audits (use `/cso-audit`)
- Code review (use `/review-army`)

---

## The 4 Phases

### PHASE 1: INVESTIGATE (Gather Evidence)

**Goal:** Collect all relevant information before forming any hypothesis.

**Actions:**
1. Read the full error message / stack trace / user report
2. Check recent changes:
   ```bash
   git log --oneline -20
   git diff HEAD~5 --stat
   ```
3. Read the project's CLAUDE.md for architectural context
4. Search for related instincts in Sinapsis (if available):
   - Read `~/.claude/skills/_instincts-index.json`
   - Search for instincts matching the error domain
   - If found, note them — they may contain the fix from a previous encounter
5. Identify the affected files (grep for error-related keywords)
6. Check for similar errors in proposals:
   - Read `~/.claude/skills/_instinct-proposals.json` if it exists

**Output to user:**
```
PHASE 1 COMPLETE — Evidence Gathered
- Error: {error summary}
- Recent changes: {N} commits in last 5
- Affected files: {list}
- Related instincts: {list or "none found"}
- Proceeding to Phase 2...
```

**Do NOT** propose any fix during this phase.

---

### PHASE 2: ANALYZE (Understand the System)

**Goal:** Trace the data flow and understand why the system behaves this way.

**Actions:**
1. Read ALL affected files completely (not just the error line)
2. Trace the data flow: input -> transformation -> output
3. Identify state mutations and side effects
4. Map the dependency chain (what calls what)
5. Check for race conditions, timing issues, or order-of-operations problems
6. Look for recent environment changes (.env, dependencies, config)

**Output to user:**
```
PHASE 2 COMPLETE — System Analysis
- Data flow: {A} -> {B} -> {C}
- The failure occurs between {B} and {C}
- Key observation: {what's unexpected}
- Proceeding to Phase 3...
```

**Do NOT** propose any fix during this phase.

---

### PHASE 3: HYPOTHESIZE (Formulate and Test)

**Goal:** Form 2-3 hypotheses ranked by probability, then verify the top one.

**Actions:**
1. List 2-3 hypotheses with supporting/refuting evidence:
   ```
   Hypothesis 1 (80%): {description}
     Supporting: {evidence}
     Refuting: {evidence or "none"}

   Hypothesis 2 (15%): {description}
     Supporting: {evidence}
     Refuting: {evidence}
   ```
2. Design a minimal test for the top hypothesis:
   - Add a `console.log`, read a value, run a specific test
   - The test should CONFIRM or REJECT the hypothesis, not fix anything
3. Execute the test
4. If rejected, move to Hypothesis 2 and repeat

**IRON LAW:** Do NOT proceed to Phase 4 until a root cause is CONFIRMED by evidence.

**Output to user:**
```
PHASE 3 COMPLETE — Root Cause Confirmed
- Root cause: {specific description}
- Confirmed by: {what test/evidence proved it}
- Hypothesis 1 was {CONFIRMED/REJECTED}: {why}
- Proceeding to Phase 4...
```

---

### PHASE 4: IMPLEMENT (Fix with Verification)

**Goal:** Apply the minimal fix, verify it works, check for regressions.

**Actions:**
1. Implement the MINIMAL fix — change only what's necessary
2. Verify the fix resolves the original symptom:
   - Run the failing test / reproduce the scenario
   - Confirm the error no longer occurs
3. Check for regressions:
   - Run related tests if they exist
   - Check that the fix doesn't break adjacent functionality
4. Log the fix as a potential new instinct if it's a reusable pattern

**Scope Freeze:** Only edit files identified in Phase 1 as affected. If you need to edit a file outside the scope, ask the user for permission first.

**Output to user:**
```
PHASE 4 COMPLETE — Fix Applied
- Root cause: {description}
- Fix: {what was changed and why}
- Verified: {how it was tested}
- Regressions: {none found / list}
- New learning: {instinct suggestion or "none — known pattern"}
```

---

## Scope Freeze Rules

During investigation, track the set of files identified as related to the bug. Before any Edit or Write:

1. Check if the target file is in the scope set
2. If YES: proceed
3. If NO: ask the user: "This file is outside the investigation scope. Edit anyway? (y/n)"

This prevents scope creep during debugging — a common cause of introducing new bugs while fixing old ones.

---

## Integration with Sinapsis

### Before Investigation
- Search `_instincts-index.json` for instincts matching the error domain
- If a matching instinct exists with the fix, show it to the user: "Sinapsis has seen this before: {inject text}"

### After Fix
- If the root cause represents a new pattern (not already an instinct):
  - Suggest adding it as a draft instinct
  - Format: `{domain}-{brief-description}` with trigger pattern matching the error
- Log the investigation to session timeline (if available):
  ```bash
  bash ~/.claude/skills/_timeline-log.sh investigate-pro completed root_cause="{brief}" phases=4
  ```

---

## Edge Cases

- **Multiple root causes:** Complete all 4 phases for each root cause separately
- **Cannot reproduce:** Document in Phase 1, ask user for reproduction steps
- **Fix requires architectural change:** Document in Phase 4, propose as separate task — do not expand scope
- **Permissions/env issue:** Document clearly, do not modify system config without asking
- **Intermittent bug:** Add logging in Phase 3 to capture state on next occurrence

---

## What NOT to Do

- Do NOT skip phases — even if you think you know the answer
- Do NOT fix before confirming root cause (Iron Law)
- Do NOT edit files outside the investigation scope without asking
- Do NOT add unrelated improvements while fixing a bug
- Do NOT run destructive commands (drop tables, delete data, force push)
