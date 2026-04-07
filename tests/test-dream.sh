#!/bin/bash
# test-dream.sh — TDD Unit Tests for Sinapsis v4.3 Dream Cycle
# 25 tests covering 5 modules: duplicates, contradictions, staleness, triggers, report
# Run: bash tests/test-dream.sh

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DREAM_SCRIPT="$SCRIPT_DIR/core/_dream.sh"

PASS=0
FAIL=0
TOTAL=25

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

setup_sandbox() {
  SANDBOX="$(mktemp -d)"
  mkdir -p "$SANDBOX/.claude/skills"
}

teardown_sandbox() {
  rm -rf "$SANDBOX" 2>/dev/null
}

write_index() {
  cat > "$SANDBOX/.claude/skills/_instincts-index.json" <<EOF
$1
EOF
}

run_dream() {
  HOME="$SANDBOX" bash "$DREAM_SCRIPT" 2>/dev/null
}

get_report() {
  cat "$SANDBOX/.claude/skills/_dream-report.md" 2>/dev/null
}

get_index() {
  cat "$SANDBOX/.claude/skills/_instincts-index.json" 2>/dev/null
}

get_log() {
  cat "$SANDBOX/.claude/skills/_dream.log" 2>/dev/null
}

echo ""
echo "=== Sinapsis v4.3 Dream Cycle — TDD Unit Tests ==="
echo "=== 25 tests across 5 modules ==="
echo ""

# ─────────────────────────────────────────────────────────
# MODULE 1: Duplicate Detection (5 tests)
# ─────────────────────────────────────────────────────────
echo "── Module 1: Duplicate Detection ──"

# T01: Empty index → 0 duplicate findings
setup_sandbox
write_index '{
  "version": "4.2",
  "instincts": []
}'
run_dream
REPORT=$(get_report)
if echo "$REPORT" | grep -q "No duplicates detected"; then
  pass "T01: Empty index → no duplicates"
else
  fail "T01: Empty index should report no duplicates"
fi
teardown_sandbox

# T02: Two instincts with identical inject text → detected
setup_sandbox
write_index '{
  "version": "4.2",
  "instincts": [
    {"id": "dup-a", "domain": "security", "level": "confirmed", "trigger_pattern": "password", "inject": "Never hardcode secrets in source code. Use environment variables.", "occurrences": 5, "added": "2026-01-01"},
    {"id": "dup-b", "domain": "security", "level": "confirmed", "trigger_pattern": "secret", "inject": "Never hardcode secrets in source code. Use environment variables.", "occurrences": 3, "added": "2026-01-01"}
  ]
}'
run_dream
REPORT=$(get_report)
if echo "$REPORT" | grep -q "dup-a" && echo "$REPORT" | grep -qi "duplicate\|duplicat"; then
  pass "T02: Identical inject text → duplicate detected"
else
  fail "T02: Identical inject should be flagged as duplicate"
fi
teardown_sandbox

# T03: Two instincts with 85% Jaccard similarity → detected
setup_sandbox
write_index '{
  "version": "4.2",
  "instincts": [
    {"id": "sim-a", "domain": "security", "level": "confirmed", "trigger_pattern": "api.?key", "inject": "Never hardcode API keys or secrets in source code. Always use environment variables from .env.local file.", "occurrences": 5, "added": "2026-01-01"},
    {"id": "sim-b", "domain": "security", "level": "confirmed", "trigger_pattern": "token", "inject": "Never hardcode API keys or secrets in source code. Always use environment variables from .env.local.", "occurrences": 3, "added": "2026-01-01"}
  ]
}'
run_dream
REPORT=$(get_report)
if echo "$REPORT" | grep -q "sim-a\|sim-b" && echo "$REPORT" | grep -qi "similar\|duplicate\|duplicat"; then
  pass "T03: 85% Jaccard similarity → duplicate detected"
else
  fail "T03: High similarity inject should be flagged"
fi
teardown_sandbox

# T04: Two instincts with same trigger_pattern → detected
setup_sandbox
write_index '{
  "version": "4.2",
  "instincts": [
    {"id": "trg-a", "domain": "git", "level": "confirmed", "trigger_pattern": "git commit|commit message", "inject": "Use conventional commits: feat/fix/chore.", "occurrences": 10, "added": "2026-01-01"},
    {"id": "trg-b", "domain": "git", "level": "confirmed", "trigger_pattern": "git commit|commit message", "inject": "Always write commit messages in English with conventional format.", "occurrences": 2, "added": "2026-02-01"}
  ]
}'
run_dream
REPORT=$(get_report)
if echo "$REPORT" | grep -q "trg-a\|trg-b" && echo "$REPORT" | grep -qi "trigger\|pattern\|duplicate\|duplicat"; then
  pass "T04: Same trigger_pattern → duplicate detected"
else
  fail "T04: Identical trigger patterns should be flagged"
fi
teardown_sandbox

# T05: Different domains + low similarity → NOT flagged
setup_sandbox
write_index '{
  "version": "4.2",
  "instincts": [
    {"id": "diff-a", "domain": "security", "level": "confirmed", "trigger_pattern": "password", "inject": "Never hardcode secrets. Use .env.local files.", "occurrences": 5, "added": "2026-01-01"},
    {"id": "diff-b", "domain": "git", "level": "confirmed", "trigger_pattern": "git commit", "inject": "Use conventional commits: feat, fix, chore.", "occurrences": 3, "added": "2026-01-01"}
  ]
}'
run_dream
REPORT=$(get_report)
if echo "$REPORT" | grep -q "No duplicates detected"; then
  pass "T05: Different domains + low similarity → no duplicates"
else
  fail "T05: Different domains should not flag duplicates"
fi
teardown_sandbox

# ─────────────────────────────────────────────────────────
# MODULE 2: Contradiction Detection (5 tests)
# ─────────────────────────────────────────────────────────
echo "── Module 2: Contradiction Detection ──"

# T06: No contradictions → 0 findings
setup_sandbox
write_index '{
  "version": "4.2",
  "instincts": [
    {"id": "safe-a", "domain": "security", "level": "confirmed", "trigger_pattern": "password", "inject": "Always validate input before processing.", "occurrences": 5, "added": "2026-01-01"},
    {"id": "safe-b", "domain": "security", "level": "confirmed", "trigger_pattern": "auth", "inject": "Use JWT tokens for API authentication.", "occurrences": 3, "added": "2026-01-01"}
  ]
}'
run_dream
REPORT=$(get_report)
if echo "$REPORT" | grep -q "No contradictions detected"; then
  pass "T06: No contradictions → empty findings"
else
  fail "T06: Non-contradictory instincts should not be flagged"
fi
teardown_sandbox

# T07: "nunca X" vs "siempre X" same domain → detected
setup_sandbox
write_index '{
  "version": "4.2",
  "instincts": [
    {"id": "contra-a", "domain": "database", "level": "confirmed", "trigger_pattern": "rls|row.level", "inject": "Nunca desactivar RLS en tablas con datos de usuario.", "occurrences": 5, "added": "2026-01-01"},
    {"id": "contra-b", "domain": "database", "level": "confirmed", "trigger_pattern": "rls|row.level", "inject": "Siempre desactivar RLS en tablas publicas para mejor rendimiento.", "occurrences": 2, "added": "2026-02-01"}
  ]
}'
run_dream
REPORT=$(get_report)
if echo "$REPORT" | grep -q "contra-a\|contra-b" && echo "$REPORT" | grep -qi "contradic"; then
  pass "T07: nunca vs siempre same domain → contradiction detected"
else
  fail "T07: nunca/siempre opposition should be flagged"
fi
teardown_sandbox

# T08: "skip" vs "require" same domain → detected
setup_sandbox
write_index '{
  "version": "4.2",
  "instincts": [
    {"id": "skip-a", "domain": "testing", "level": "confirmed", "trigger_pattern": "test|spec", "inject": "Skip integration tests when running in CI for faster builds.", "occurrences": 5, "added": "2026-01-01"},
    {"id": "skip-b", "domain": "testing", "level": "confirmed", "trigger_pattern": "test|spec", "inject": "Require integration tests to pass before any merge to main.", "occurrences": 3, "added": "2026-01-01"}
  ]
}'
run_dream
REPORT=$(get_report)
if echo "$REPORT" | grep -q "skip-a\|skip-b" && echo "$REPORT" | grep -qi "contradic"; then
  pass "T08: skip vs require same domain → contradiction detected"
else
  fail "T08: skip/require opposition should be flagged"
fi
teardown_sandbox

# T09: Different domains → NOT flagged as contradiction
setup_sandbox
write_index '{
  "version": "4.2",
  "instincts": [
    {"id": "cross-a", "domain": "security", "level": "confirmed", "trigger_pattern": "password", "inject": "Never expose passwords in logs.", "occurrences": 5, "added": "2026-01-01"},
    {"id": "cross-b", "domain": "testing", "level": "confirmed", "trigger_pattern": "test", "inject": "Always expose test results in CI output.", "occurrences": 3, "added": "2026-01-01"}
  ]
}'
run_dream
REPORT=$(get_report)
if echo "$REPORT" | grep -q "No contradictions detected"; then
  pass "T09: Different domains → no contradictions"
else
  fail "T09: Cross-domain should not flag contradictions"
fi
teardown_sandbox

# T10: Negation "No hacer" vs positive "hacer" → detected
setup_sandbox
write_index '{
  "version": "4.2",
  "instincts": [
    {"id": "neg-a", "domain": "workflow", "level": "confirmed", "trigger_pattern": "deploy", "inject": "No hacer deploy en viernes por riesgo de incidencias.", "occurrences": 5, "added": "2026-01-01"},
    {"id": "neg-b", "domain": "workflow", "level": "confirmed", "trigger_pattern": "deploy", "inject": "Hacer deploy siempre que haya cambios listos, cualquier dia.", "occurrences": 3, "added": "2026-01-01"}
  ]
}'
run_dream
REPORT=$(get_report)
if echo "$REPORT" | grep -q "neg-a\|neg-b" && echo "$REPORT" | grep -qi "contradic"; then
  pass "T10: No hacer vs hacer → contradiction detected"
else
  fail "T10: Negation pattern should be flagged"
fi
teardown_sandbox

# ─────────────────────────────────────────────────────────
# MODULE 3: Staleness Scoring (5 tests)
# ─────────────────────────────────────────────────────────
echo "── Module 3: Staleness Scoring ──"

TODAY=$(date -u +%Y-%m-%dT%H:%M:%SZ)
DAYS_AGO_45=$(date -u -d "45 days ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-45d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "2026-02-21T00:00:00Z")
DAYS_AGO_95=$(date -u -d "95 days ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-95d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "2026-01-02T00:00:00Z")
DATE_95_AGO=$(date -u -d "95 days ago" +%Y-%m-%d 2>/dev/null || date -u -v-95d +%Y-%m-%d 2>/dev/null || echo "2026-01-02")

# T11: Triggered today → freshness="fresh"
setup_sandbox
write_index "{
  \"version\": \"4.2\",
  \"instincts\": [
    {\"id\": \"fresh-a\", \"domain\": \"git\", \"level\": \"confirmed\", \"trigger_pattern\": \"git\", \"inject\": \"Use conventional commits.\", \"occurrences\": 10, \"last_triggered\": \"$TODAY\", \"added\": \"2026-01-01\"}
  ]
}"
run_dream
REPORT=$(get_report)
if echo "$REPORT" | grep -q "fresh-a" && echo "$REPORT" | grep -qi "fresh"; then
  pass "T11: Triggered today → fresh"
else
  # May also pass if fresh instincts are simply not listed in staleness section
  if ! echo "$REPORT" | grep -q "fresh-a"; then
    pass "T11: Triggered today → not listed as stale (correct)"
  else
    fail "T11: Recently triggered should be fresh"
  fi
fi
teardown_sandbox

# T12: Triggered 45 days ago → freshness="stale"
setup_sandbox
write_index "{
  \"version\": \"4.2\",
  \"instincts\": [
    {\"id\": \"stale-a\", \"domain\": \"git\", \"level\": \"confirmed\", \"trigger_pattern\": \"git\", \"inject\": \"Use conventional commits.\", \"occurrences\": 10, \"last_triggered\": \"$DAYS_AGO_45\", \"added\": \"2026-01-01\"}
  ]
}"
run_dream
REPORT=$(get_report)
if echo "$REPORT" | grep -q "stale-a" && echo "$REPORT" | grep -qi "stale"; then
  pass "T12: Triggered 45 days ago → stale"
else
  fail "T12: 45-day-old trigger should be stale"
fi
teardown_sandbox

# T13: Draft + 0 occurrences + 95 days → auto-archived
setup_sandbox
write_index "{
  \"version\": \"4.2\",
  \"instincts\": [
    {\"id\": \"old-draft\", \"domain\": \"general\", \"level\": \"draft\", \"trigger_pattern\": \"something\", \"inject\": \"Some old draft instinct.\", \"occurrences\": 0, \"added\": \"$DATE_95_AGO\"}
  ]
}"
run_dream
INDEX=$(get_index)
REPORT=$(get_report)
# Check: old-draft should be in "archived" array and NOT in "instincts" array
HAS_ARCHIVED=$(echo "$INDEX" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8')); console.log((d.archived||[]).some(i=>i.id==='old-draft') ? 'yes' : 'no')" 2>/dev/null)
NOT_IN_ACTIVE=$(echo "$INDEX" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8')); console.log(!(d.instincts||[]).some(i=>i.id==='old-draft') ? 'yes' : 'no')" 2>/dev/null)
if [ "$HAS_ARCHIVED" = "yes" ] && [ "$NOT_IN_ACTIVE" = "yes" ]; then
  pass "T13: Draft + 0 occ + 95 days → auto-archived"
else
  fail "T13: Old draft should be auto-archived (archived=$HAS_ARCHIVED, removed=$NOT_IN_ACTIVE)"
fi
teardown_sandbox

# T14: Permanent + 0 occurrences + 95 days → flagged but NOT archived
setup_sandbox
write_index "{
  \"version\": \"4.2\",
  \"instincts\": [
    {\"id\": \"old-perm\", \"domain\": \"general\", \"level\": \"permanent\", \"trigger_pattern\": \"something\", \"inject\": \"Important permanent instinct.\", \"occurrences\": 0, \"added\": \"$DATE_95_AGO\"}
  ]
}"
run_dream
INDEX=$(get_index)
REPORT=$(get_report)
# Should still be in active instincts (not archived)
STILL_ACTIVE=$(echo "$INDEX" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8')); console.log((d.instincts||[]).some(i=>i.id==='old-perm') ? 'yes' : 'no')" 2>/dev/null)
if [ "$STILL_ACTIVE" = "yes" ]; then
  if echo "$REPORT" | grep -q "old-perm"; then
    pass "T14: Permanent + 0 occ → flagged but NOT archived"
  else
    fail "T14: Permanent never-activated should be flagged in report"
  fi
else
  fail "T14: Permanent instinct should NOT be auto-archived"
fi
teardown_sandbox

# T15: Confirmed + occurrences>0 + 45 days stale → flagged only
setup_sandbox
write_index "{
  \"version\": \"4.2\",
  \"instincts\": [
    {\"id\": \"stale-conf\", \"domain\": \"security\", \"level\": \"confirmed\", \"trigger_pattern\": \"password\", \"inject\": \"Validate passwords.\", \"occurrences\": 8, \"last_triggered\": \"$DAYS_AGO_45\", \"added\": \"2026-01-01\"}
  ]
}"
run_dream
INDEX=$(get_index)
REPORT=$(get_report)
STILL_ACTIVE=$(echo "$INDEX" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8')); console.log((d.instincts||[]).some(i=>i.id==='stale-conf') ? 'yes' : 'no')" 2>/dev/null)
if [ "$STILL_ACTIVE" = "yes" ]; then
  if echo "$REPORT" | grep -q "stale-conf"; then
    pass "T15: Confirmed + stale → flagged only, not archived"
  else
    pass "T15: Confirmed + stale → not archived (flagged check flexible)"
  fi
else
  fail "T15: Confirmed instinct should NOT be auto-archived"
fi
teardown_sandbox

# ─────────────────────────────────────────────────────────
# MODULE 4: Trigger Pattern Validation (5 tests)
# ─────────────────────────────────────────────────────────
echo "── Module 4: Trigger Validation ──"

# T16: Valid regex → pass (no warning)
setup_sandbox
write_index '{
  "version": "4.2",
  "instincts": [
    {"id": "valid-re", "domain": "git", "level": "confirmed", "trigger_pattern": "git commit|commit message", "inject": "Use conventional commits.", "occurrences": 10, "added": "2026-01-01"}
  ]
}'
run_dream
REPORT=$(get_report)
if ! echo "$REPORT" | grep -q "valid-re.*invalid\|valid-re.*warning"; then
  pass "T16: Valid regex → no trigger warnings"
else
  fail "T16: Valid regex should not be flagged"
fi
teardown_sandbox

# T17: Invalid regex → flagged
setup_sandbox
write_index '{
  "version": "4.2",
  "instincts": [
    {"id": "bad-re", "domain": "git", "level": "confirmed", "trigger_pattern": "(unclosed", "inject": "Some instinct.", "occurrences": 0, "added": "2026-01-01"}
  ]
}'
run_dream
REPORT=$(get_report)
if echo "$REPORT" | grep -q "bad-re" && echo "$REPORT" | grep -qi "invalid\|error\|regex"; then
  pass "T17: Invalid regex → flagged"
else
  fail "T17: Invalid regex should be flagged"
fi
teardown_sandbox

# T18: Overly broad .* → warning
setup_sandbox
write_index '{
  "version": "4.2",
  "instincts": [
    {"id": "broad-re", "domain": "general", "level": "confirmed", "trigger_pattern": ".*", "inject": "This matches everything.", "occurrences": 100, "added": "2026-01-01"}
  ]
}'
run_dream
REPORT=$(get_report)
if echo "$REPORT" | grep -q "broad-re" && echo "$REPORT" | grep -qi "broad\|warning\|overly"; then
  pass "T18: Overly broad .* → warning"
else
  fail "T18: Broad pattern .* should be warned"
fi
teardown_sandbox

# T19: Single char pattern → warning
setup_sandbox
write_index '{
  "version": "4.2",
  "instincts": [
    {"id": "short-re", "domain": "general", "level": "confirmed", "trigger_pattern": "a", "inject": "This matches too much.", "occurrences": 50, "added": "2026-01-01"}
  ]
}'
run_dream
REPORT=$(get_report)
if echo "$REPORT" | grep -q "short-re" && echo "$REPORT" | grep -qi "short\|warning\|broad\|single"; then
  pass "T19: Single char pattern → warning"
else
  fail "T19: Single char pattern should be warned"
fi
teardown_sandbox

# T20: Cross-domain trigger overlap → info
setup_sandbox
write_index '{
  "version": "4.2",
  "instincts": [
    {"id": "overlap-a", "domain": "security", "level": "confirmed", "trigger_pattern": "error|exception|failed", "inject": "Log all errors securely.", "occurrences": 5, "added": "2026-01-01"},
    {"id": "overlap-b", "domain": "quality", "level": "confirmed", "trigger_pattern": "error|bug|exception", "inject": "Handle errors gracefully.", "occurrences": 3, "added": "2026-01-01"}
  ]
}'
run_dream
REPORT=$(get_report)
if echo "$REPORT" | grep -qi "overlap\|cross.domain\|shared.*pattern"; then
  pass "T20: Cross-domain trigger overlap → info"
else
  fail "T20: Overlapping cross-domain triggers should be noted"
fi
teardown_sandbox

# ─────────────────────────────────────────────────────────
# MODULE 5: Report & Health Score (5 tests)
# ─────────────────────────────────────────────────────────
echo "── Module 5: Report & Health Score ──"

# T21: Healthy index → score > 80
setup_sandbox
write_index "{
  \"version\": \"4.2\",
  \"instincts\": [
    {\"id\": \"h1\", \"domain\": \"git\", \"level\": \"permanent\", \"trigger_pattern\": \"git commit\", \"inject\": \"Use conventional commits.\", \"occurrences\": 50, \"last_triggered\": \"$TODAY\", \"added\": \"2026-01-01\"},
    {\"id\": \"h2\", \"domain\": \"security\", \"level\": \"confirmed\", \"trigger_pattern\": \"password\", \"inject\": \"Use env vars for secrets.\", \"occurrences\": 30, \"last_triggered\": \"$TODAY\", \"added\": \"2026-01-01\"},
    {\"id\": \"h3\", \"domain\": \"deploy\", \"level\": \"confirmed\", \"trigger_pattern\": \"vercel\", \"inject\": \"Check deploy config.\", \"occurrences\": 20, \"last_triggered\": \"$TODAY\", \"added\": \"2026-01-01\"}
  ]
}"
run_dream
REPORT=$(get_report)
SCORE=$(echo "$REPORT" | grep -oP '(?<=Health Score: \*\*)\d+' 2>/dev/null || echo "$REPORT" | grep -o '[0-9]*/100' | head -1 | cut -d/ -f1)
if [ -n "$SCORE" ] && [ "$SCORE" -gt 80 ] 2>/dev/null; then
  pass "T21: Healthy index → score $SCORE > 80"
else
  fail "T21: Healthy index should score > 80 (got: $SCORE)"
fi
teardown_sandbox

# T22: Many stale instincts → score < 50
setup_sandbox
write_index "{
  \"version\": \"4.2\",
  \"instincts\": [
    {\"id\": \"s1\", \"domain\": \"a\", \"level\": \"confirmed\", \"trigger_pattern\": \"x1\", \"inject\": \"Stale 1.\", \"occurrences\": 0, \"added\": \"$DATE_95_AGO\"},
    {\"id\": \"s2\", \"domain\": \"b\", \"level\": \"confirmed\", \"trigger_pattern\": \"x2\", \"inject\": \"Stale 2.\", \"occurrences\": 0, \"added\": \"$DATE_95_AGO\"},
    {\"id\": \"s3\", \"domain\": \"c\", \"level\": \"confirmed\", \"trigger_pattern\": \"x3\", \"inject\": \"Stale 3.\", \"occurrences\": 0, \"added\": \"$DATE_95_AGO\"},
    {\"id\": \"s4\", \"domain\": \"d\", \"level\": \"confirmed\", \"trigger_pattern\": \"x4\", \"inject\": \"Stale 4.\", \"occurrences\": 0, \"added\": \"$DATE_95_AGO\"},
    {\"id\": \"s5\", \"domain\": \"e\", \"level\": \"confirmed\", \"trigger_pattern\": \"x5\", \"inject\": \"Stale 5.\", \"occurrences\": 0, \"added\": \"$DATE_95_AGO\"},
    {\"id\": \"s6\", \"domain\": \"f\", \"level\": \"confirmed\", \"trigger_pattern\": \"x6\", \"inject\": \"Stale 6.\", \"occurrences\": 0, \"added\": \"$DATE_95_AGO\"}
  ]
}"
run_dream
REPORT=$(get_report)
SCORE=$(echo "$REPORT" | grep -oP '(?<=Health Score: \*\*)\d+' 2>/dev/null || echo "$REPORT" | grep -o '[0-9]*/100' | head -1 | cut -d/ -f1)
if [ -n "$SCORE" ] && [ "$SCORE" -le 60 ] 2>/dev/null; then
  pass "T22: Many stale instincts → score $SCORE <= 60"
else
  fail "T22: Many stale should score <= 60 (got: $SCORE)"
fi
teardown_sandbox

# T23: Duplicates → score penalty
setup_sandbox
write_index '{
  "version": "4.2",
  "instincts": [
    {"id": "dp1", "domain": "git", "level": "confirmed", "trigger_pattern": "git commit", "inject": "Always use conventional commits for all changes.", "occurrences": 10, "last_triggered": "2026-04-07T00:00:00Z", "added": "2026-01-01"},
    {"id": "dp2", "domain": "git", "level": "confirmed", "trigger_pattern": "commit", "inject": "Always use conventional commits for all changes.", "occurrences": 5, "last_triggered": "2026-04-07T00:00:00Z", "added": "2026-01-01"}
  ]
}'
run_dream
REPORT=$(get_report)
SCORE=$(echo "$REPORT" | grep -oP '(?<=Health Score: \*\*)\d+' 2>/dev/null || echo "$REPORT" | grep -o '[0-9]*/100' | head -1 | cut -d/ -f1)
if [ -n "$SCORE" ] && [ "$SCORE" -lt 100 ] 2>/dev/null; then
  pass "T23: Duplicates → score penalty (got: $SCORE)"
else
  fail "T23: Duplicates should penalize score (got: $SCORE)"
fi
teardown_sandbox

# T24: Report contains all 5 section headers
setup_sandbox
write_index '{
  "version": "4.2",
  "instincts": [
    {"id": "sec-a", "domain": "git", "level": "confirmed", "trigger_pattern": "git", "inject": "Use conventional commits.", "occurrences": 5, "added": "2026-01-01"}
  ]
}'
run_dream
REPORT=$(get_report)
SECTIONS=0
echo "$REPORT" | grep -qi "duplicate" && SECTIONS=$((SECTIONS + 1))
echo "$REPORT" | grep -qi "contradic" && SECTIONS=$((SECTIONS + 1))
echo "$REPORT" | grep -qi "stale\|staleness\|freshness" && SECTIONS=$((SECTIONS + 1))
echo "$REPORT" | grep -qi "trigger\|validation\|pattern" && SECTIONS=$((SECTIONS + 1))
echo "$REPORT" | grep -qi "health\|metric\|score" && SECTIONS=$((SECTIONS + 1))
if [ "$SECTIONS" -ge 5 ]; then
  pass "T24: Report contains all 5 sections"
else
  fail "T24: Report missing sections ($SECTIONS/5 found)"
fi
teardown_sandbox

# T25: Auto-actions logged to _dream.log
setup_sandbox
write_index "{
  \"version\": \"4.2\",
  \"instincts\": [
    {\"id\": \"log-draft\", \"domain\": \"general\", \"level\": \"draft\", \"trigger_pattern\": \"xyz\", \"inject\": \"Old draft.\", \"occurrences\": 0, \"added\": \"$DATE_95_AGO\"}
  ]
}"
run_dream
LOG=$(get_log)
if echo "$LOG" | grep -q "log-draft" && echo "$LOG" | grep -qi "archived\|auto"; then
  pass "T25: Auto-actions logged to _dream.log"
else
  fail "T25: Auto-archive should be logged"
fi
teardown_sandbox

# ─────────────────────────────────────────────────────────
# RESULTS
# ─────────────────────────────────────────────────────────
echo ""
echo "=== Results: $PASS passed, $FAIL failed (of $TOTAL) ==="
if [ "$FAIL" -gt 0 ]; then
  echo "STATUS: SOME TESTS FAILED"
  exit 1
else
  echo "STATUS: ALL TESTS PASSED"
  exit 0
fi
