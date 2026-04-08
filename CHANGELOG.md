# Changelog

## v4.3.1 (2026-04-08)

### Fixed — Fersora Audit (22 bugs + 6 vulnerabilities)
- **#1-3**: install.sh preserves user data on upgrade (instincts, rules, projects, operator state)
- **#4/5A**: execFileSync replaces execSync (command injection prevention)
- **#5**: Auto-promote works correctly (drafts track occurrences without injecting)
- **#6**: Race condition fix (dream lock check before index write)
- **#7/5E**: fcntl.flock on JSONL writes
- **#8**: Token catalog corrected (9,995 → 6,915 after cleanup)
- **#9**: install.bat synced to v4.3.1
- **#10-11**: Command schemas match reality
- **#12/5C**: ReDoS protection on trigger patterns
- **#13**: Jaccard Unicode support
- **#14**: Contradiction false positive reduction
- **#15**: session-end/eod documented
- **#16**: tmpdir cleanup
- **#17**: session-learner selects by recency not hash
- **#18**: operator-state schema flag
- **#19**: KNOWLEDGE_FILE dead code removed
- **#20**: synapis → sinapsis rename
- **#22**: SINAPSIS_DEBUG mode
- **5B**: +4 secret patterns (GitHub, JWT, AWS, Stripe)
- **5D**: chmod 600 on data files
- **5F**: Inject sanitization (500 char limit + blocked patterns)

### Directory Audit Cleanup
- **Removed**: `skills/sinapsis-researcher/` (contradicts d011 — moved to on-demand)
- **Removed**: `skills/sinapsis-optimizer/` (90% duplicated by `commands/skill-audit.md`)
- **Removed**: `commands/clone.md` (100% duplicated by skill-router Section 4)
- **Removed**: `docs/synapis-technical-docs.docx` (typo + obsolete v3.2 content)
- **Fixed**: Portable find in `_session-learner.sh` (stat fallback for macOS)
- **Fixed**: fcntl Windows compatibility in `observe_v3.py` (try/except fallback)
- **Fixed**: install.bat now creates `.last-learn` marker
- **Fixed**: `_catalog.json` reduced to 3 global skills (was 5)
- **Fixed**: `.gitignore` expanded from 1 line to 12 patterns
- **Token savings**: ~4,080 tokens/session (~41% reduction)

### Tests
- 52/52 GREEN (25 dream + 11 security + 16 orchestrator)

---

## v4.3.0 (2026-04-08)

### Added
- **Dream Cycle** (`core/_dream.sh`): 5-module index hygiene system inspired by Anthropic's AutoDream
  - Module 1: Duplicate detection (Jaccard word tokens, threshold 0.80)
  - Module 2: Contradiction detection (7 opposing keyword pairs, EN+ES)
  - Module 3: Staleness scoring (fresh/stale/archive_candidate/never_activated)
  - Module 4: Trigger pattern validation (regex validity, overly broad, cross-domain overlap)
  - Module 5: Index health metrics and score (0-100)
- `/dream` command (`commands/dream.md`): Interactive dream cycle with merge/archive actions
- Auto-archive: drafts with 0 occurrences and >90 days old
- `archived` array in `_instincts-index.json` for non-destructive archival
- `_dream-report.md`: Human-readable report with executive summary and findings
- `_dream.log`: Audit trail for dream cycle actions
- Lock file (`_dream.lock`) with 1-hour stale detection

### Tests
- 25 TDD unit tests (`tests/test-dream.sh`)
- 15 E2E integration tests (`tests/test-e2e-dream.sh`)
- Total: 40 new tests (was 78, now 118)

### Improved
- Health score formula now penalizes `never_activated` instincts (-5 each)
- Empty index generates minimal report instead of silently exiting

---

## v4.2.2 — 2026-04-06

### Added
- **Multi-project /eod**: `_eod-gather.sh` deterministic script scans ALL projects worked today via homunculus, aggregates git data per project root, outputs structured JSON for consolidated EOD summary
- **`_eod-gather.sh`**: new helper script in `core/` — reads homunculus/projects/ for today's observations, cross-references projects.json for names/roots, runs git log/status/branch per project
- **`/session-end` command**: added to `commands/` — was missing from installer, users couldn't see the command
- **E2E pipeline test**: 25 tests across 6 stages (observe → learn → activate → gather → bridge → integrity) in isolated sandbox
- **12 TDD tests** for `_eod-gather.sh`: multi-project detection, stale skip, hash fallback, observation counts, schema validation

### Fixed
- **`projectName` scope bug in `_session-learner.sh`**: variable was declared inside JOB 1 try/catch but used in JOB 2 outside it → `ReferenceError` silenced by `2>/dev/null` — proposals were never written since v4.2.0. Discovered by E2E test.
- **`eod.md` single-project limitation**: now uses `_eod-gather.sh` instead of running git commands against current directory only

### Changed
- Test count: 37 → 78 (21 unit + 12 TDD + 25 E2E + 20 security)
- `install.sh` version bumped to v4.2.2, now copies `_eod-gather.sh`

---

## v4.2.1 — 2026-04-06

### Added
- **Occurrences tiebreaker** in domain dedup: when two instincts share the same domain and level, the one with more occurrences wins (inspired by fs-cortex confidence granularity — credit: Fernando Montero)
- **Domain pre-filter by project stack**: reads `context.md` to detect project tech, skips instincts from irrelevant domains before regex matching

### Changed
- Instinct activator sort: level priority preserved, occurrences used as secondary sort key
- Domain dedup: `ALWAYS_DOMAINS` set (general, git, security, operations, quality) always passes pre-filter

---

## v4.2.0 — 2026-04-05

### Added
- **3 pattern detectors** in `_session-learner.sh`: error-fix (improved), user-corrections, workflow-chains
- **Occurrence tracking** in `_instinct-activator.sh`: each instinct match increments `occurrences`, `first_triggered`, `last_triggered`
- **Auto-promote**: draft instincts with 5+ occurrences automatically promoted to confirmed
- **Atomic writes**: instinct-activator uses tmp + rename to prevent index corruption
- **Enriched proposals**: `project_name`, `sample_input`, `sample_output` in every proposal
- **13 TDD tests** covering all 3 patterns + occurrence tracking + auto-promote + atomic writes

### Changed
- Session learner window: 100 → 1000 lines (covers parallel sessions)
- Instincts index schema v4.2: added `occurrences`, `first_triggered`, `last_triggered` fields

### Fixed
- 97% of observations were silently discarded per session (100/~3000+)
- Proposals were generic — now include project context and samples

---

## v4.1.1 — 2026-04-01

### Fixed: Critical — Auto-resume between sessions was broken
`_project-context.sh` had a stray `break` (line 57) outside the conditional block. If today's EOD summary didn't exist, the loop would exit immediately without checking yesterday's file. The flagship auto-resume feature was completely non-functional.

### Fixed: `/analyze-session` command didn't exist
README, CHANGELOG, install output, and multiple SKILL.md files all referenced `/analyze-session`, but the actual command file was named `analyze-observations.md`. Renamed to `analyze-session.md` and rewrote content for v4.1 proposals workflow.

### Fixed: `install.bat` parity with `install.sh`
- Added `_daily-summaries` directory creation (missing — `/eod` would fail on Windows)
- Added Python 3 detection with warning (was silent)
- Fixed Node.js path quoting using `process.argv` (paths with spaces would break)

### Fixed: `.last-learn` marker created at install time
`_session-learner.sh` uses `find -newer .last-learn` which would fail noisily on first run. Installer now creates the marker file.

### Fixed: 11 files referenced non-existent v3.2 paths
- `_instincts.json` → `_instincts-index.json` (8 files)
- `_observations.json` → `~/.claude/homunculus/projects/{hash}/observations.jsonl` (3 files)
- Fixed `skills/homunculus` path → `homunculus` (no `skills/` prefix)
- Fixed `lastSeen` field reference → v4.1 schema fields

### Fixed: Version and naming inconsistencies
- Bumped version 3.2 → 4.1 in `_catalog.json`, `_projects.json`, `_operator-state.template.json`
- Renamed "Synapis" → "Sinapsis" across all `.md` and `.json` files
- Skill Router header: v3.0 → v4.1
- `settings.template.json`: corrected hook count 7/Stop(2) → 6/Stop(1)

### Updated: Command and skill files to v4.1 data model
- Rewrote `synapis-instincts/SKILL.md`: replaced 0.0-1.0 lifecycle model with draft/confirmed/permanent
- Rewrote `instinct-status.md`: dashboard now shows levels and domain dedup
- Rewrote `promote.md`: promotes confirmed → permanent (not project → global)
- Updated `evolve.md`: filter criteria uses levels, not confidence decimals

### Improved: Error detection in `observe_v3.py`
Replaced substring matching (`"error" in output`) with word-boundary regex patterns. Prevents false positives like "0 errors found" from being flagged as errors.

### Improved: Removed orphan directory creation in `observe_v3.py`
Removed creation of unused directories (`instincts/personal`, `evolved/skills`, etc.) per project. Only creates the project directory itself.

---

## v4.1 — 2026-03-31

### New: Closed Learning Pipeline
The observation→learning→injection pipeline is now fully connected end-to-end:

1. `observe.sh` (PreToolUse + PostToolUse): writes `observations.jsonl` per project
2. `_session-learner.sh` (Stop hook): reads observations, detects error patterns, writes `_instinct-proposals.json`
3. `/analyze-session`: review proposals, accept → add to `_instincts-index.json`
4. `_instinct-activator.sh` (PreToolUse): reads index, injects matched instincts as `systemMessage`

### New: Project Context Bridge
`_session-learner.sh` writes `context.md` per project at session end (project name, last session date, files touched, gotcha count hint).
`_project-context.sh` reads it at the first PreToolUse of the next session — fires once per session via session_id flag.

### New: Domain Deduplication in Instinct Activator
`_instinct-activator.sh` groups instincts by domain. One instinct per domain is injected, max 3 total.
Prevents multiple contradictory instincts from the same area firing simultaneously.
Priority: `permanent` > `confirmed`.

### New: 3-Level Confidence Model
Replaces the 0.0–1.0 decimal scoring with 3 explicit levels:
- `draft`: proposed by session-learner, not injected. Review with `/analyze-session`.
- `confirmed`: validated by user. Injected silently when trigger matches.
- `permanent`: explicitly promoted via `/promote`. Highest priority in domain dedup.

### New: `_instincts-index.json`
Central instinct registry. Replaces scattered YAML files.
Fields: `id`, `domain`, `level`, `trigger_pattern`, `inject`, `origin`, `added`.
Origin values: `manual` (curated) or `learned` (from session-learner).

### New: `core/settings.template.json`
Documents the 6-hook architecture with comments. Copy/merge into `~/.claude/settings.json`.

### Changed: Honest Observation Model
v3.2 claimed Sinapsis "observes passively in real-time." This was inaccurate.
v4.1 is explicit: hooks are deterministic bash scripts. Claude does NOT analyze observations during a session.
Analysis happens at Stop (deterministic) or on demand (`/analyze-session`).

### Changed: Token Architecture
- 2 global skills always active (was 5): skill-router + sinapsis-learning
- Instinct injection: ~50–200 tokens per matching tool use (only matched instincts)
- Passive rules: ~20–80 tokens per matching tool use (only matched rules)
- Full `_instincts-index.json` and `_passive-rules.json` read by hooks, not loaded into LLM context

### Fixed: Noise in Proposals
v3.2 session-learner generated 80+ noise proposals per day (workflow sequences, tool preferences).
v4.1 only detects `error_resolution` patterns (error → same tool success within 5 events), with dedup per tool per day.

---

## v3.2 — Initial public release

Skills on Demand architecture. Passive rules, skill router, operator state, 5 global always-on skills.
