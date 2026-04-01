# Sinapsis Optimizer v1.0

> Context optimization skill. Manages token budgets, audits skill overhead,
> detects redundancy, and keeps the system lean.

---

## When to Use

Trigger on:
- "How much context am I using?", "Token budget"
- "Which skills are costing the most?", "Optimize my setup"
- "Clean up skills", "Reduce overhead"
- `/skill-audit`, `/system-status` (token section)
- Any concern about context window usage or performance

---

## Token Budget Model

### Estimation Method

Token count is estimated from file size:
```
tokens ~= file_size_in_bytes / 4
```

This is approximate but sufficient for budget planning.

### Budget Categories

```
CONTEXT WINDOW BUDGET (~200,000 tokens typical)

  Category              Tokens    % of Budget
  --------------------  --------  -----------
  System prompt          ~2,000     1.0%
  CLAUDE.md              ~1,500     0.8%
  Active skills         ~12,000     6.0%
  Passive rules            ~800     0.4%
  Operator state           ~600     0.3%
  Conversation history  ~80,000    40.0%   (grows during session)
  Available for work   ~103,100    51.5%

  Status: HEALTHY -- plenty of room
```

### Budget Thresholds

| Usage | Status | Action |
|-------|--------|--------|
| < 15% fixed overhead | GREEN | No action needed |
| 15-25% fixed overhead | YELLOW | Review for optimization |
| 25-40% fixed overhead | ORANGE | Recommend cleanup |
| > 40% fixed overhead | RED | Urgent: too many skills loaded |

---

## Skill Audit

### Per-Skill Breakdown

```
SKILL TOKEN AUDIT

  #  Skill                    File Size   Est. Tokens   Last Used
  1. skill-router              8.2 KB       ~2,050      today
  2. synapis-learning          6.1 KB       ~1,525      today
  3. synapis-instincts         7.4 KB       ~1,850      today
  4. synapis-researcher        5.8 KB       ~1,450      3 days ago
  5. synapis-optimizer         4.9 KB       ~1,225      today
  6. api-builder               3.6 KB         ~900      1 week ago
  7. proposal-writer           4.4 KB       ~1,100      2 weeks ago
  8. old-helper                2.0 KB         ~500      never

  TOTAL ACTIVE SKILLS: 8
  TOTAL TOKEN OVERHEAD: ~10,600 tokens/session

  INSTALLED COMMANDS:
  1. /evolve                   2.8 KB         ~700
  2. /clone                    1.6 KB         ~400
  3. /system-status            2.0 KB         ~500

  TOTAL COMMANDS: 3
  TOTAL COMMAND OVERHEAD: ~1,600 tokens/session

  GRAND TOTAL: ~12,200 tokens fixed overhead (6.1% of budget)
```

---

## Redundancy Detection

### How It Works

1. **Name similarity**: Skills with similar names (>60% string match)
2. **Tag overlap**: Skills sharing >70% of their tags
3. **Trigger overlap**: Skills with identical or near-identical triggers
4. **Content similarity**: Skills covering the same domain with similar instructions

### Redundancy Report

```
REDUNDANCY ANALYSIS

  POTENTIAL DUPLICATES:
  1. "api-builder" + "endpoint-creator"
     Tag overlap: 85%
     Trigger overlap: 3 shared triggers
     Recommendation: MERGE -- save ~900 tokens
     [M] Merge  [K] Keep both  [X] Skip

  SUPERSEDED SKILLS:
  2. "old-helper" is a subset of "synapis-optimizer"
     Coverage: old-helper features are 100% covered
     Recommendation: REMOVE old-helper -- save ~500 tokens
     [R] Remove  [K] Keep  [X] Skip

  NO ISSUES FOUND:
  - skill-router (unique role)
  - synapis-learning (unique role)
  - synapis-instincts (unique role)
```

---

## Compression Suggestions

For skills that are too large:

```
COMPRESSION OPPORTUNITIES

  1. synapis-instincts (7.4 KB / ~1,850 tokens)
     - 40% of content is examples -- could move to separate doc
     - Estimated savings: ~600 tokens
     [C] Compress  [X] Skip

  2. proposal-writer (4.4 KB / ~1,100 tokens)
     - Contains 3 template sections rarely used
     - Estimated savings: ~300 tokens
     [C] Compress  [X] Skip
```

### Compression Strategies

1. **Extract examples**: Move examples to a separate file, reference on demand
2. **Deduplicate sections**: Remove repeated instructions across skills
3. **Trim unused sections**: Remove sections that never trigger
4. **Condense formatting**: Reduce whitespace and verbose descriptions
5. **Split skill**: Break a large skill into core + extension

---

## Memory Cleanup

### Observation Log

```
MEMORY STATUS

  Observations: 342 entries (last 90 days)
  Active observations: 127 (< 30 days old)
  Stale observations: 215 (> 30 days, no related instinct)

  Recommendation: Archive 215 stale observations
  Estimated savings: ~8,600 tokens if loaded

  [A] Archive stale  [K] Keep all  [X] Skip
```

### Instinct Cleanup

```
INSTINCT STATUS

  Total: 43 instincts
  Active (confidence >= 0.5): 31
  Stale (no hit in 60+ days): 7
  Low confidence (< 0.3): 5

  Recommendations:
  1. Archive 5 low-confidence instincts (likely noise)
  2. Review 7 stale instincts (may be obsolete)

  [1] Archive low-conf  [2] Review stale  [A] Both  [X] Skip
```

---

## Display Format

### Quick Summary (for /system-status)

```
OPTIMIZER: Token overhead ~12,200 (6.1%) [GREEN]
  8 skills + 3 commands | 0 redundancies | 0 issues
```

### Full Report (for /skill-audit)

Shows all sections above: per-skill breakdown, redundancy analysis,
compression suggestions, and memory cleanup.

---

## Automatic Recommendations

Sinapsis Optimizer passively monitors and will suggest:

1. **After 10+ sessions without using a skill**: "Consider archiving {skill} -- unused for {N} sessions"
2. **When installing a new skill**: "This overlaps 60% with {existing-skill}. Merge instead?"
3. **When token overhead exceeds 20%**: "Your fixed overhead is high. Run /skill-audit?"
4. **When observation log exceeds 300 entries**: "Observation log is large. Run cleanup?"

These suggestions appear once and can be dismissed.

---

## Integration Points

- **Skill Router**: Provides token data for installation decisions
- **Sinapsis Learning**: Monitors observation log size
- **Sinapsis Instincts**: Reports instinct count and health
- **/system-status**: Contributes the token budget section
- **/skill-audit**: Full deep audit command
