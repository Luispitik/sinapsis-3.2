# /dream -- Dream Cycle (Index Hygiene)

> Run the 5-module deterministic analysis on _instincts-index.json.
> Detects duplicates, contradictions, stale instincts, invalid patterns,
> and computes health metrics. Inspired by Anthropic's AutoDream.

---

## Trigger

Run with `/dream`, "dream cycle", "index hygiene", "consolidate instincts".

---

## Process

### Step 1: Run Dream Cycle

Execute `bash ~/.claude/skills/_dream.sh`
Read the generated report from `~/.claude/skills/_dream-report.md`
Display the full report to the user.

### Step 2: Review Findings

For each finding, display:
- **Duplicates**: Show both instinct IDs, similarity score, and suggest merge
- **Contradictions**: Show both instinct IDs and the opposing statements
- **Stale instincts**: Show ID, days since last trigger, occurrences count
- **Trigger issues**: Show ID and the specific problem

### Step 3: Interactive Actions (if findings exist)

For each proposed action, ask the user:
- **[M] Merge** — Combine duplicate instincts (merge trigger_patterns with |, keep higher-level instinct, archive the other)
- **[A] Archive** — Move instinct to archived array in _instincts-index.json
- **[K] Keep** — Dismiss finding, take no action

User responds with format: "1M 2K 3A" (finding number + action letter)

### Step 4: Execute User Choices

For merges:
  - Combine trigger_patterns with | operator
  - Keep the instinct with higher level (permanent > confirmed > draft)
  - If same level, keep the one with more occurrences
  - Move the other to archived array

For archives:
  - Move from instincts[] to archived[] in _instincts-index.json
  - Atomic write (tmp + rename)

### Step 5: Summary

Show:
  - Number of actions taken
  - Updated health score (re-run _dream.sh if actions were taken)
  - Remind about /instinct-status for full dashboard

---

## Edge Cases

- **No instincts index**: Show "No instincts index found. Run /analyze-session first."
- **No dream report**: If `_dream-report.md` doesn't exist after running, show "Dream cycle produced no report. Check _dream.log for errors."
- **Clean index**: If no findings, show "Index is healthy! Health score: {score}/100. No actions needed."
- **Script failure**: If _dream.sh fails, show stderr and suggest checking Node.js version.
