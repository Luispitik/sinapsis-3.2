# Changelog

## v4.5.0 (2026-04-18) — unreleased

### Added — Laws tier (inspired by fs-cortex, credit: Fernando Montero / MIT)
- **`core/_laws-injector.sh`** (new SessionStart hook): emits `SESSION_PREFETCH_LAWS:` lines from `~/.claude/skills/_laws/*.txt`. Max 10 laws per session, cap ~300 tokens (conservative 4 chars/token). Rotates by `last_injected` ASC for variety across sessions. Atomic write (tmp → rename) survives concurrent sessions.
- **`seeds/laws/*.txt`** (5 ported seeds, MIT © Fernando Montero): `read-first`, `grep-read-verify`, `git-triple-check`, `never-hardcode-secrets`, `three-layer-security`.
- **`seeds/laws/README.md`**: schema + attribution.
- **Law model**: `Law = one-line projection of a permanent instinct (or stand-alone seed)`. `source_instinct: null` → stand-alone. `/promote --law` distills a permanent instinct into a Law (see `commands/promote.md` Step 4).
- **10 TDD tests** (`tests/test-laws.sh`): presence, seed count, empty-dir silent exit, emission format, MAX_LAWS cap, `last_injected` atomic update, rotation ordering, malformed-file resilience, whitespace normalization. 10/10 GREEN.

### Changed
- `install.sh`: copies `_laws-injector.sh` + seed laws into `~/.claude/skills/_laws/` (idempotent; existing files preserve their `last_injected`).
- `core/settings.template.json`: adds `SessionStart` hooks section (`_hooks_total`: 6 → 7, `_hooks_breakdown`: `SessionStart(1) + PreToolUse(4) + PostToolUse(1) + Stop(1)`).
- `commands/promote.md`: adds Step 4 "Offer Law Distillation" — when an instinct is promoted to `permanent`, user can accept a suggested one-liner to write into `_laws/`.

### Rationale
Sinapsis already projected patterns as instincts (regex-gated, per-tool-use injection). What was missing: a thin tier of **always-on crystallized wisdom** — the 5-10 principles the user never wants to risk forgetting, no matter the context. Matches fs-cortex's `laws` concept without replacing instincts: laws are a *projection* of permanents, not a parallel registry. Existing commands (`/promote`, `/evolve`) keep working unchanged; the hook is purely additive at the end of the SessionStart array.

### Test badge
116 → 126 passing (suite-wide, 8 test files).

---

## v4.4.1 (2026-04-17)

### Fixed
- **`_session-learner.sh` line 277 — bash quoting bug (regression)**: the regex `["']?` inside `node -e '...'` closed the bash single-quoted string prematurely, causing every Stop event to crash with `syntax error near unexpected token (`. Pattern 4 (repetitions) and Pattern 5 (agent-patterns) never ran. Replaced literal `'` in the regex char class with the JS unicode escape `\u0027`. Added regression test (`bash -n` of all `core/*.sh`).
- **`_projects.json` was never populated**: every reader (`/projects`, `/eod`, `/instinct-status`, `/evolve`, `/backup`, `_session-learner.sh`, `_eod-gather.sh`) consulted `_projects.json` or `homunculus/projects.json` but no hook ever wrote to either. The registry stayed empty forever, so `_eod-gather.sh` could not resolve `hash → name` (showed raw 12-char hashes), `/projects` was always blank, and cross-project instinct search returned nothing. `_session-learner.sh` now upserts the canonical `~/.claude/skills/_projects.json` (array schema) on every Stop event with `{id, name, root, remote, created, last_seen}`. Project name is sourced from observation `project_name` (already written by `observe.sh`) with legacy `homunculus/projects.json` fallback. Atomic write via tmp + rename. Advisory lock file (`_projects.json.lock`) with `O_EXCL` + backoff + stale detection prevents lost updates when parallel Stop hooks fire concurrently. Idempotent.
- **`_eod-gather.sh` registry path**: switched primary source to canonical `~/.claude/skills/_projects.json` (array schema) so `/eod` resolves names correctly. Legacy `homunculus/projects.json` (map schema) kept as fallback for back-compat.
- **`_catalog.json` trailing comma**: invalid JSON. Python `json.load()` failed; Node tolerated but it is fragile. Removed the comma.
- **`_session-learner.sh` derives `root`/`remote` from observation `cwd`**: derive them via `git rev-parse --show-toplevel` + `git remote get-url origin` against the most recent observation `cwd`. POSIX `/c/foo` paths are normalized to `C:/foo` on Windows so native `git.exe` accepts them. Without this, `_projects.json` entries had blank `root`/`remote` even when upsert succeeded.
- **`observe_v3.py` now writes `cwd` into every observation**: the session-learner reads `lines[i].cwd` to run `git rev-parse`, but the hook never wrote that field — so root/remote stayed empty on fresh installs. Added `cwd` to the observation dict.

### Tests
- 4 new regression tests in `tests/test-install-upgrade.sh` (Test Group 6): bash syntax of all `core/*.sh`, `_projects.json` upsert detects `name`, idempotency on repeat run, and an end-to-end TEST 14 that pipes a real payload through `observe.sh` into a real git sandbox and verifies session-learner derives `root`/`remote` from observation `cwd` via `git rev-parse`.

---

## v4.4.0 (2026-04-16)

### Added — Observability Dashboard
- **`/dashboard-sinapsis`** command: regenerates `~/.claude/skills/_dashboard.html` — a self-contained visual dashboard with real data parsed from all pipeline files. Editorial design (Instrument Serif + warm accents on deep ink).
- **`core/_generate-dashboard.py`**: deterministic Python generator. Parses `_instincts-index.json`, `_passive-rules.json`, `_passive.log`, `_instinct-proposals.json`, `_instinct.log`, `_catalog.json`, `_projects.json`, `_operator-state.json` and `homunculus/projects/*/observations.jsonl`. Computes hero KPIs, velocity (new instincts per week), hour-of-day distribution, 21-day activity heatmap, maturation averages (add→first_triggered), funnel metrics, top-10 leaderboards and dead-instincts list. Portable: honors `$SINAPSIS_HOME` env var or falls back to `~/.claude/`.
- **`core/_dashboard-template.html`**: HTML template with `/*__SINAPSIS_DATA__*/null` injection marker. Chart.js + Google Fonts via CDN. Dark editorial theme with serif display + Inter + JetBrains Mono. Responsive.
- **12 TDD tests** (`tests/test-dashboard.sh`): portability, template substitution, metric computation, dead detection, level counting, domain aggregation, empty-state graceful handling.

### Changed
- `install.sh`: +2 files installed (`_generate-dashboard.py`, `_dashboard-template.html`)
- Test badge: 83 → 95 passing

### Rationale
Sinapsis already had `/instinct-status`, `/passive-status` and `/system-status` for terminal inspection. None gave a holistic, at-a-glance view of the learning system's health, velocity or maturation timings. The dashboard surfaces what the existing commands couldn't: **how fast you're learning, when the system fires, and where the dead weight is**.

---

## v4.3.3 (2026-04-13)

### Added — Hardening from Cortex Comparison (credit: Fernando Montero / fs-cortex v3.10)
- **`/downvote`** command: demote or archive instincts that give bad advice. Closes the feedback loop.
- **3 extra scrubbing patterns** in `observe_v3.py`: Stripe (`sk_live/sk_test`), Slack (`xoxb/xoxp`), SendGrid (`SG.*`). Now 8 patterns total (was 5).
- **Path traversal protection** in `_instinct-activator.sh`: blocks inject content containing `../`, `~/`, `/etc/`, `/proc/`.
- **Token budget cap** (`TOKEN_BUDGET=1500`): limits total chars injected per tool use. Prevents instinct loops.
- **Multi-session auto-promote**: drafts now require 5+ occurrences AND 3+ distinct sessions to promote. Tracks `sessions_seen[]` per instinct. (Was: 5+ occurrences in any number of sessions.)
- **2 new pattern detectors** in `_session-learner.sh`: repetitions (same error in 3+ sessions) and agent patterns (subagent error capture). Now 5 detectors total (was 3).
- **GitHub Actions CI**: test suite runs on push/PR across Ubuntu, macOS, Windows.
- **Pre-push hook**: `.githooks/pre-push` blocks push if any test suite fails. Enable: `git config core.hooksPath .githooks`
- **Legacy file cleanup** in `install.sh`: removes obsolete files from v3.2/v4.4 on upgrade (gstack skills, old skill names, clone.md).

### Changed
- `observe_v3.py`: 5 → 8 scrubbing patterns
- `_instinct-activator.sh`: path traversal check, budget cap, multi-session tracking
- `_session-learner.sh`: 3 → 5 pattern detectors (+ repetitions + agent patterns)
- `install.sh`: legacy cleanup step added

### Portability & Cleanup
- **`/backup [path]`** command: export full Sinapsis state to a portable folder for sync or migration between machines. Exports instincts, rules, operator state, commands, settings, CLAUDE.md + manifest.
- **`/restore [path]`** command: import Sinapsis state from a backup folder with intelligent merge (by ID, keeps local occurrence data, asks before overwriting machine-specific files).
- **`/cleanup`** command: clean homunculus directory — removes v1 legacy files (config.json, identity.json, instincts/, evolved/, exports/, root observations), orphan projects (30+ days inactive), and old archives (60+ days).

### Tests
- 14 new TDD tests (`tests/test-v433-hardening.sh`)

---

## v4.3.2 (2026-04-12)

### Removed — GStack Separation (focus: autonomous learning only)
- **`/review-army`**, **`/cso-audit`**, **`/investigate-pro`** skills moved out (engineering tools, not learning)
- **`/retro-semanal`** command moved out (reporting, not learning)
- **`_timeline-log.sh`** helper moved out (infrastructure for removed skills)
- **`__pycache__/observe_v3.cpython-314.pyc`** removed from git tracking
- All 5 components archived to `~/.claude/skills/_archived/sinapsis-gstack/` with recovery guide
- Version badges and references cleaned back to v4.3

### Kept from v4.4
- **Confidence decay** in `_instinct-activator.sh` (learning hygiene — confirmed 60d→draft, draft 90d→archived)
- **Cross-project search** in `/instinct-status --cross-project` (learning infrastructure)

---

## v4.4 (2026-04-09) — SUPERSEDED by v4.3.2

### Added — GStack Integration (garrytan/gstack) — MOVED OUT
- **Confidence decay** in `_instinct-activator.sh`: confirmed(60d inactive) -> draft, draft(90d inactive) -> archived. Permanent never decays. Credit: garrytan/gstack learnings confidence decay.
- **`/review-army`** skill: 5 specialist parallel code review (security, nextjs, supabase, performance, testing). Fix-First workflow, quality scoring. Tested live on mission-control (8.5/10, 3 findings, 0 false positives).
- **`/cso-audit`** skill: OWASP Top 10 + STRIDE + supply chain + LLM security audit. Daily mode (8/10 gate) and comprehensive mode (2/10 gate).
- **`/investigate-pro`** skill: 4-phase systematic debugging (investigate -> analyze -> hypothesize -> implement). Iron Law: no fix without confirmed root cause. Scope freeze via hooks.
- **Session timeline** (`_session-timeline.jsonl`): JSONL event log for skill usage tracking, context recovery, and retrospectives. Helper: `_timeline-log.sh`.
- **`/retro-semanal`** command: Weekly metrics across all projects — commits, skills used, instincts activated, health score trend, recommendations.
- **Cross-project instinct search** in `/instinct-status --cross-project`: search instincts across all registered projects in `_projects.json` without promoting.

### Changed
- `_catalog.json`: +3 skills (review-army, cso-audit, investigate-pro)
- `/instinct-status`: rewritten for v4.4 data model (draft/confirmed/permanent levels, occurrence tracking, cross-project search)

### Inspiration
- garrytan/gstack (23 YC engineering skills): confidence decay, review army, CSO audit, investigate, retro, session timeline, cross-project search
- Full analysis: `gstack-integration-analysis.md`

---

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
