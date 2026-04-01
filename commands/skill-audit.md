# /skill-audit -- Deep Skill Analysis & Cleanup

> CRITICAL: This is the process for users who ALREADY have skills installed.
> Scans all installed skills and commands, calculates token overhead,
> detects duplicates and conflicts, and proposes a cleanup plan.

---

## Trigger

Run with `/skill-audit` or "audit my skills".

---

## Process

### Step 1: Scan Everything

Scan these locations:
- `~/.claude/skills/` -- global skills (always active)
- `~/.claude/commands/` -- global commands
- `.claude/commands/` -- project-level commands (current project)
- `~/.claude/skills/_library/` -- dormant library skills (not loaded, but available)

For each file found:
- Read file size
- Estimate token count: `tokens ~= file_size_bytes / 4`
- Extract metadata (name, description, triggers) if available
- Record last modified date

### Step 2: Analyze

#### Token Overhead Calculation

```
TOKEN OVERHEAD ANALYSIS

  ALWAYS-ACTIVE SKILLS (loaded every session):
  #  Skill                    Size      Tokens   Last Modified
  1. skill-router/SKILL.md    8.2 KB    ~2,050   2 days ago
  2. synapis-learning/SKILL.md 6.1 KB   ~1,525   2 days ago
  3. synapis-instincts/SKILL.md 7.4 KB  ~1,850   2 days ago
  4. synapis-researcher/SKILL.md 5.8 KB ~1,450   5 days ago
  5. synapis-optimizer/SKILL.md 4.9 KB  ~1,225   2 days ago
  ─────────────────────────────────────────────
  Subtotal: 5 skills                    ~8,100 tokens

  GLOBAL COMMANDS:
  6. evolve.md                 2.8 KB     ~700   1 week ago
  7. clone.md                  1.6 KB     ~400   1 week ago
  8. system-status.md          2.0 KB     ~500   1 week ago
  9. passive-status.md         1.2 KB     ~300   1 week ago
  10. instinct-status.md       1.8 KB     ~450   1 week ago
  11. promote.md               1.0 KB     ~250   2 weeks ago
  12. analyze-session.md       2.4 KB     ~600   1 week ago
  13. projects.md              1.4 KB     ~350   1 week ago
  14. skill-audit.md           3.2 KB     ~800   today
  ─────────────────────────────────────────────
  Subtotal: 9 commands                  ~4,350 tokens

  PROJECT COMMANDS (current project):
  15. api-builder.md           3.6 KB     ~900   2 weeks ago
  16. testing-suite.md         5.6 KB   ~1,400   1 week ago
  17. deploy-helper.md         2.0 KB     ~500   3 weeks ago
  18. old-linter.md            1.6 KB     ~400   2 months ago
  ─────────────────────────────────────────────
  Subtotal: 4 project commands          ~3,200 tokens

  GRAND TOTAL: 18 files = ~15,650 tokens/session (7.8% of budget)
```

#### Duplicate Detection

Compare all skills/commands pairwise:
- **Name similarity**: Levenshtein distance < 40% of name length
- **Trigger overlap**: Shared trigger words
- **Tag overlap**: > 70% shared tags
- **Content overlap**: Similar instruction patterns

#### Conflict Detection

Look for contradictions:
- Skill A says "always do X", Skill B says "never do X"
- Two skills claim the same trigger with different actions
- Redundant rules that could interfere

#### Usage Analysis

- Check last modified dates as proxy for usage
- Flag skills not modified in 60+ days
- Check if any skill has 0 references from other skills

### Step 3: Present Cleanup Proposal

```
SKILL AUDIT -- Your Installation

  Skills active:            18 files
  Token overhead estimated: ~15,650 tokens/session (7.8%)

  ════════════════════════════════════════════
  CLEANUP PROPOSAL
  ════════════════════════════════════════════

  DUPLICATES DETECTED (merge recommended):
  ────────────────────────────────────────
  1. deploy-helper.md + evolve.md deploy section
     Overlap: deploy-helper duplicates 80% of evolve's deploy logic
     Savings: ~500 tokens
     [M] Merge into evolve  [K] Keep both  [X] Skip

  LOW USAGE (archive recommended):
  ────────────────────────────────
  2. old-linter.md (last modified: 2 months ago)
     No references from other skills
     Savings: ~400 tokens
     [A] Archive  [K] Keep  [X] Skip

  OVERSIZED (compress recommended):
  ─────────────────────────────────
  3. testing-suite.md (5.6 KB / ~1,400 tokens)
     Contains 3 example sections (40% of file)
     Could extract examples to separate doc
     Savings: ~560 tokens
     [C] Compress  [K] Keep as-is  [X] Skip

  CONFLICTS DETECTED:
  ───────────────────
  4. synapis-learning says "log all observations"
     synapis-optimizer says "archive observations > 300"
     These are complementary, not conflicting (no action needed)
     [OK] Acknowledged

  NO ISSUES:
  ──────────
  - skill-router (unique orchestrator role)
  - synapis-instincts (unique knowledge base)
  - synapis-researcher (unique research role)
  - api-builder (project-specific, actively used)

  ════════════════════════════════════════════
  SAVINGS SUMMARY
  ════════════════════════════════════════════

  If all recommendations accepted:
    Merge:     -500 tokens
    Archive:   -400 tokens
    Compress:  -560 tokens
    ─────────────────────
    Total:     -1,460 tokens/session

    Before: ~15,650 tokens (7.8%)
    After:  ~14,190 tokens (7.1%)

  Enter choices (e.g., "1M 2A 3C 4OK"): _
```

### Step 4: Execute Chosen Actions

#### Merge [M]
1. Identify the target skill (the one to keep)
2. Extract unique content from the skill being removed
3. Append unique content to the target skill
4. Delete the merged skill
5. Update catalog if needed

#### Archive [A]
1. Move the skill file to `~/.claude/skills/_archived/`
2. Add archive metadata (date, reason, original location)
3. Remove from catalog
4. Show: "Archived. Recover anytime from _archived/"

#### Compress [C]
1. Identify compressible sections (examples, verbose descriptions)
2. Extract to a separate reference file
3. Replace with brief summary + "See {reference} for details"
4. Show before/after token count

#### Keep [K]
No action taken.

### Step 5: Before/After Summary

```
AUDIT COMPLETE

  BEFORE                          AFTER
  ──────                          ─────
  18 files                        16 files
  ~15,650 tokens                  ~14,190 tokens
  7.8% budget                     7.1% budget
  1 duplicate                     0 duplicates
  1 unused skill                  0 unused (1 archived)
  1 oversized skill               0 oversized (1 compressed)

  Changes applied:
  - Merged deploy-helper into evolve
  - Archived old-linter to _archived/
  - Compressed testing-suite (extracted examples)

  Recovery: archived skills can be restored from
  ~/.claude/skills/_archived/ at any time.
```

---

## Important Notes

- **Always ask permission** before archiving or merging. Show the impact first.
- **Explain WHY** each change is proposed so the user understands the reasoning.
- **Show token impact** for every proposed action.
- **Never delete permanently** -- always archive so recovery is possible.
- **Respect user choices** -- if they want to keep a seemingly redundant skill, respect that.
