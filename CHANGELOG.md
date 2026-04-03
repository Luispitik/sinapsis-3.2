# Changelog

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
