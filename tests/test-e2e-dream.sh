#!/bin/bash
# test-e2e-dream.sh — E2E Integration Tests for Sinapsis v4.3 Dream Cycle
# 15 tests running _dream.sh against fabricated sandbox data
# Run: bash tests/test-e2e-dream.sh

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DREAM_SCRIPT="$SCRIPT_DIR/core/_dream.sh"
COMMAND_FILE="$SCRIPT_DIR/commands/dream.md"

PASS=0
FAIL=0
TOTAL=15

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

# Date calculations (portable: GNU date first, then BSD fallback)
TODAY=$(date -u +%Y-%m-%dT%H:%M:%SZ)
DATE_95_AGO=$(date -u -d "95 days ago" +%Y-%m-%d 2>/dev/null || date -u -v-95d +%Y-%m-%d 2>/dev/null || echo "2026-01-02")

echo ""
echo "=== Sinapsis v4.3 Dream Cycle — E2E Integration Tests ==="
echo "=== 15 tests running _dream.sh against sandbox data ==="
echo ""

# Pre-flight: verify dream script exists
if [ ! -f "$DREAM_SCRIPT" ]; then
  echo "FATAL: _dream.sh not found at $DREAM_SCRIPT"
  echo "Build the script first, then run these tests."
  exit 1
fi

# ─────────────────────────────────────────────────────────
# E01: Empty index → report says nothing to consolidate
# ─────────────────────────────────────────────────────────
echo "── E01: Empty index ──"
setup_sandbox
write_index '{
  "version": "4.2",
  "instincts": []
}'
run_dream
REPORT=$(get_report)
if echo "$REPORT" | grep -qi "nothing to consolidate\|0 instinct\|no instincts\|empty"; then
  pass "E01: Empty index → report says nothing to consolidate"
else
  fail "E01: Empty index should report nothing to consolidate"
fi
teardown_sandbox

# ─────────────────────────────────────────────────────────
# E02: Index with duplicates → report lists merge candidates
# ─────────────────────────────────────────────────────────
echo "── E02: Duplicates → merge candidates ──"
setup_sandbox
write_index '{
  "version": "4.2",
  "instincts": [
    {"id": "e02-a", "domain": "security", "level": "confirmed", "trigger_pattern": "password|secret", "inject": "Never hardcode secrets in source code. Use environment variables.", "occurrences": 12, "added": "2026-01-01"},
    {"id": "e02-b", "domain": "security", "level": "confirmed", "trigger_pattern": "api.?key|secret", "inject": "Never hardcode secrets in source code. Use environment variables.", "occurrences": 5, "added": "2026-02-15"}
  ]
}'
run_dream
REPORT=$(get_report)
if echo "$REPORT" | grep -qi "merge\|duplicate\|duplicat" && echo "$REPORT" | grep -q "e02-a\|e02-b"; then
  pass "E02: Duplicates → report lists merge candidates"
else
  fail "E02: Duplicates should list merge candidates in report"
fi
teardown_sandbox

# ─────────────────────────────────────────────────────────
# E03: Index with contradictions → report flags for review
# ─────────────────────────────────────────────────────────
echo "── E03: Contradictions → flags for review ──"
setup_sandbox
write_index '{
  "version": "4.2",
  "instincts": [
    {"id": "e03-a", "domain": "deploy", "level": "confirmed", "trigger_pattern": "deploy|release", "inject": "Nunca hacer deploy en viernes por riesgo de incidencias de fin de semana.", "occurrences": 8, "added": "2026-01-01"},
    {"id": "e03-b", "domain": "deploy", "level": "confirmed", "trigger_pattern": "deploy|release", "inject": "Siempre hacer deploy cuando haya cambios listos, cualquier dia de la semana.", "occurrences": 3, "added": "2026-02-01"}
  ]
}'
run_dream
REPORT=$(get_report)
if echo "$REPORT" | grep -qi "contradic" && echo "$REPORT" | grep -q "e03-a\|e03-b"; then
  pass "E03: Contradictions → report flags for review"
else
  fail "E03: Contradictions should be flagged in report"
fi
teardown_sandbox

# ─────────────────────────────────────────────────────────
# E04: Stale drafts (draft, 0 occ, 95+ days) → auto-archived
# ─────────────────────────────────────────────────────────
echo "── E04: Stale drafts → auto-archived ──"
setup_sandbox
write_index "{
  \"version\": \"4.2\",
  \"instincts\": [
    {\"id\": \"e04-stale-draft\", \"domain\": \"general\", \"level\": \"draft\", \"trigger_pattern\": \"something-old\", \"inject\": \"An old unused draft instinct that should be archived.\", \"occurrences\": 0, \"added\": \"$DATE_95_AGO\"},
    {\"id\": \"e04-fresh\", \"domain\": \"git\", \"level\": \"confirmed\", \"trigger_pattern\": \"git commit\", \"inject\": \"Use conventional commits.\", \"occurrences\": 20, \"added\": \"2026-01-01\"}
  ]
}"
run_dream
INDEX=$(get_index)
# Stale draft should be moved to archived array and removed from active instincts
ARCHIVED_HAS_IT=$(echo "$INDEX" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8')); const a=d.archived||[]; process.exit(a.some(i=>i.id==='e04-stale-draft') ? 0 : 1)" 2>/dev/null && echo "yes" || echo "no")
ACTIVE_LACKS_IT=$(echo "$INDEX" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8')); process.exit(d.instincts.some(i=>i.id==='e04-stale-draft') ? 1 : 0)" 2>/dev/null && echo "yes" || echo "no")
FRESH_KEPT=$(echo "$INDEX" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8')); process.exit(d.instincts.some(i=>i.id==='e04-fresh') ? 0 : 1)" 2>/dev/null && echo "yes" || echo "no")
if [ "$ARCHIVED_HAS_IT" = "yes" ] && [ "$ACTIVE_LACKS_IT" = "yes" ] && [ "$FRESH_KEPT" = "yes" ]; then
  pass "E04: Stale draft auto-archived, fresh instinct kept"
else
  fail "E04: Stale draft should be archived (archived=$ARCHIVED_HAS_IT, removed=$ACTIVE_LACKS_IT, fresh_kept=$FRESH_KEPT)"
fi
teardown_sandbox

# ─────────────────────────────────────────────────────────
# E05: Index with invalid regex → report flags patterns
# ─────────────────────────────────────────────────────────
echo "── E05: Invalid regex → flagged ──"
setup_sandbox
write_index '{
  "version": "4.2",
  "instincts": [
    {"id": "e05-badre", "domain": "testing", "level": "confirmed", "trigger_pattern": "(unclosed[bracket", "inject": "Some instinct with a broken regex trigger.", "occurrences": 3, "added": "2026-01-01"},
    {"id": "e05-good", "domain": "git", "level": "confirmed", "trigger_pattern": "git commit|commit message", "inject": "Use conventional commits.", "occurrences": 10, "added": "2026-01-01"}
  ]
}'
run_dream
REPORT=$(get_report)
if echo "$REPORT" | grep -q "e05-badre" && echo "$REPORT" | grep -qi "invalid\|error\|regex\|pattern"; then
  pass "E05: Invalid regex → flagged in report"
else
  fail "E05: Invalid regex pattern should be flagged"
fi
teardown_sandbox

# ─────────────────────────────────────────────────────────
# E06: Only fresh confirmed instincts → checksum unchanged
# ─────────────────────────────────────────────────────────
echo "── E06: Fresh confirmed → no side effects ──"
setup_sandbox
write_index "{
  \"version\": \"4.2\",
  \"instincts\": [
    {\"id\": \"e06-a\", \"domain\": \"git\", \"level\": \"confirmed\", \"trigger_pattern\": \"git commit\", \"inject\": \"Use conventional commits.\", \"occurrences\": 50, \"last_triggered\": \"$TODAY\", \"added\": \"2026-01-01\"},
    {\"id\": \"e06-b\", \"domain\": \"security\", \"level\": \"confirmed\", \"trigger_pattern\": \"password\", \"inject\": \"Use env vars for secrets.\", \"occurrences\": 30, \"last_triggered\": \"$TODAY\", \"added\": \"2026-01-01\"}
  ]
}"
# Capture checksum before
CHECKSUM_BEFORE=$(md5sum "$SANDBOX/.claude/skills/_instincts-index.json" 2>/dev/null | cut -d' ' -f1 || md5 -q "$SANDBOX/.claude/skills/_instincts-index.json" 2>/dev/null)
run_dream
CHECKSUM_AFTER=$(md5sum "$SANDBOX/.claude/skills/_instincts-index.json" 2>/dev/null | cut -d' ' -f1 || md5 -q "$SANDBOX/.claude/skills/_instincts-index.json" 2>/dev/null)
if [ "$CHECKSUM_BEFORE" = "$CHECKSUM_AFTER" ]; then
  pass "E06: Fresh confirmed instincts → index unchanged"
else
  fail "E06: Index should not be modified when all instincts are fresh"
fi
teardown_sandbox

# ─────────────────────────────────────────────────────────
# E07: Lock file exists → script exits without running
# ─────────────────────────────────────────────────────────
echo "── E07: Lock file → no-op exit ──"
setup_sandbox
write_index '{
  "version": "4.2",
  "instincts": [
    {"id": "e07-a", "domain": "git", "level": "confirmed", "trigger_pattern": "git", "inject": "Conventional commits.", "occurrences": 5, "added": "2026-01-01"}
  ]
}'
# Create a fresh lock file (less than 1 hour old)
echo "$$" > "$SANDBOX/.claude/skills/_dream.lock"
run_dream
EXIT_CODE=$?
REPORT_EXISTS="no"
[ -f "$SANDBOX/.claude/skills/_dream-report.md" ] && REPORT_EXISTS="yes"
if [ "$EXIT_CODE" -eq 0 ] && [ "$REPORT_EXISTS" = "no" ]; then
  pass "E07: Lock file exists → exit 0, no report written"
else
  fail "E07: Should exit cleanly without writing report (exit=$EXIT_CODE, report=$REPORT_EXISTS)"
fi
teardown_sandbox

# ─────────────────────────────────────────────────────────
# E08: Lock file cleaned up after normal run
# ─────────────────────────────────────────────────────────
echo "── E08: Lock cleanup after run ──"
setup_sandbox
write_index '{
  "version": "4.2",
  "instincts": [
    {"id": "e08-a", "domain": "git", "level": "confirmed", "trigger_pattern": "git", "inject": "Conventional commits.", "occurrences": 5, "added": "2026-01-01"}
  ]
}'
# No pre-existing lock — the script should create one during run and remove it after
run_dream
if [ ! -f "$SANDBOX/.claude/skills/_dream.lock" ]; then
  pass "E08: Lock file cleaned up after normal run"
else
  fail "E08: Lock file should be removed after successful run"
fi
teardown_sandbox

# ─────────────────────────────────────────────────────────
# E09: Stale lock file (>1 hour old) → auto-removed, script runs
# ─────────────────────────────────────────────────────────
echo "── E09: Stale lock → auto-removed ──"
setup_sandbox
write_index '{
  "version": "4.2",
  "instincts": [
    {"id": "e09-a", "domain": "git", "level": "confirmed", "trigger_pattern": "git", "inject": "Conventional commits.", "occurrences": 5, "added": "2026-01-01"}
  ]
}'
# Create lock file and backdate it to Jan 1 2026 (well over 1 hour old)
echo "12345" > "$SANDBOX/.claude/skills/_dream.lock"
touch -t 202601010000 "$SANDBOX/.claude/skills/_dream.lock"
run_dream
REPORT=$(get_report)
if [ -n "$REPORT" ] && [ ! -f "$SANDBOX/.claude/skills/_dream.lock" ]; then
  pass "E09: Stale lock auto-removed, script ran normally"
else
  LOCK_GONE="no"
  [ ! -f "$SANDBOX/.claude/skills/_dream.lock" ] && LOCK_GONE="yes"
  fail "E09: Stale lock should be auto-removed and script should run (report_exists=$([ -n "$REPORT" ] && echo yes || echo no), lock_gone=$LOCK_GONE)"
fi
teardown_sandbox

# ─────────────────────────────────────────────────────────
# E10: Report format has Dream Report header and all sections
# ─────────────────────────────────────────────────────────
echo "── E10: Report format validation ──"
setup_sandbox
write_index "{
  \"version\": \"4.2\",
  \"instincts\": [
    {\"id\": \"e10-a\", \"domain\": \"git\", \"level\": \"confirmed\", \"trigger_pattern\": \"git commit\", \"inject\": \"Use conventional commits.\", \"occurrences\": 10, \"added\": \"2026-01-01\"},
    {\"id\": \"e10-b\", \"domain\": \"security\", \"level\": \"draft\", \"trigger_pattern\": \"password\", \"inject\": \"Validate passwords.\", \"occurrences\": 0, \"added\": \"$DATE_95_AGO\"}
  ]
}"
run_dream
REPORT=$(get_report)
CHECKS=0
# Must have Dream Report header
echo "$REPORT" | grep -qi "dream report\|dream cycle" && CHECKS=$((CHECKS + 1))
# Must have duplicates section
echo "$REPORT" | grep -qi "duplicate" && CHECKS=$((CHECKS + 1))
# Must have contradictions section
echo "$REPORT" | grep -qi "contradic" && CHECKS=$((CHECKS + 1))
# Must have staleness section
echo "$REPORT" | grep -qi "stale\|staleness\|freshness\|archiv" && CHECKS=$((CHECKS + 1))
# Must have trigger validation section
echo "$REPORT" | grep -qi "trigger\|pattern\|validation\|regex" && CHECKS=$((CHECKS + 1))
if [ "$CHECKS" -ge 5 ]; then
  pass "E10: Report has Dream Report header and all $CHECKS/5 sections"
else
  fail "E10: Report missing sections ($CHECKS/5 found)"
fi
teardown_sandbox

# ─────────────────────────────────────────────────────────
# E11: Atomic write safety — no .tmp files left behind
# ─────────────────────────────────────────────────────────
echo "── E11: Atomic write safety ──"
setup_sandbox
write_index '{
  "version": "4.2",
  "instincts": [
    {"id": "e11-a", "domain": "git", "level": "confirmed", "trigger_pattern": "git", "inject": "Conventional commits.", "occurrences": 5, "added": "2026-01-01"}
  ]
}'
run_dream
TMP_FILES=$(find "$SANDBOX/.claude/skills/" -name "*.tmp" -o -name "*.swp" -o -name "*~" 2>/dev/null | wc -l)
if [ "$TMP_FILES" -eq 0 ]; then
  pass "E11: No .tmp files left behind after run"
else
  fail "E11: Found $TMP_FILES temp files after run"
fi
teardown_sandbox

# ─────────────────────────────────────────────────────────
# E12: Run twice → second run has fewer/equal findings (idempotent)
# ─────────────────────────────────────────────────────────
echo "── E12: Idempotent on double run ──"
setup_sandbox
write_index "{
  \"version\": \"4.2\",
  \"instincts\": [
    {\"id\": \"e12-draft\", \"domain\": \"general\", \"level\": \"draft\", \"trigger_pattern\": \"old-thing\", \"inject\": \"Old draft to archive.\", \"occurrences\": 0, \"added\": \"$DATE_95_AGO\"},
    {\"id\": \"e12-dup-a\", \"domain\": \"security\", \"level\": \"confirmed\", \"trigger_pattern\": \"secret\", \"inject\": \"Never hardcode secrets anywhere.\", \"occurrences\": 5, \"added\": \"2026-01-01\"},
    {\"id\": \"e12-dup-b\", \"domain\": \"security\", \"level\": \"confirmed\", \"trigger_pattern\": \"api.key\", \"inject\": \"Never hardcode secrets anywhere.\", \"occurrences\": 3, \"added\": \"2026-02-01\"}
  ]
}"
# First run
run_dream
REPORT_1=$(get_report)
FINDINGS_1=$(echo "$REPORT_1" | grep -ci "duplicate\|contradic\|stale\|invalid\|archived\|warning\|flag" 2>/dev/null || echo "0")
# Second run (after auto-actions from first run modified the index)
run_dream
REPORT_2=$(get_report)
FINDINGS_2=$(echo "$REPORT_2" | grep -ci "duplicate\|contradic\|stale\|invalid\|archived\|warning\|flag" 2>/dev/null || echo "0")
if [ "$FINDINGS_2" -le "$FINDINGS_1" ]; then
  pass "E12: Second run findings ($FINDINGS_2) <= first run ($FINDINGS_1)"
else
  fail "E12: Second run should have fewer/equal findings (run1=$FINDINGS_1, run2=$FINDINGS_2)"
fi
teardown_sandbox

# ─────────────────────────────────────────────────────────
# E13: dream.md command file exists with Trigger/Process sections
# ─────────────────────────────────────────────────────────
echo "── E13: dream.md command file ──"
if [ -f "$COMMAND_FILE" ]; then
  CMD_CONTENT=$(cat "$COMMAND_FILE")
  HAS_TRIGGER="no"
  HAS_PROCESS="no"
  echo "$CMD_CONTENT" | grep -qi "trigger" && HAS_TRIGGER="yes"
  echo "$CMD_CONTENT" | grep -qi "process\|steps\|procedure\|workflow" && HAS_PROCESS="yes"
  if [ "$HAS_TRIGGER" = "yes" ] && [ "$HAS_PROCESS" = "yes" ]; then
    pass "E13: dream.md exists with Trigger and Process sections"
  else
    fail "E13: dream.md missing Trigger ($HAS_TRIGGER) or Process ($HAS_PROCESS) section"
  fi
else
  fail "E13: dream.md command file not found at $COMMAND_FILE"
fi

# ─────────────────────────────────────────────────────────
# E14: Script reads _knowledge-index.md without crashing
# ─────────────────────────────────────────────────────────
echo "── E14: Knowledge index integration ──"
setup_sandbox
write_index '{
  "version": "4.2",
  "instincts": [
    {"id": "e14-a", "domain": "git", "level": "confirmed", "trigger_pattern": "git commit", "inject": "Use conventional commits.", "occurrences": 10, "added": "2026-01-01"}
  ]
}'
# Create a _knowledge-index.md file (Karpathy linting output)
cat > "$SANDBOX/.claude/skills/_knowledge-index.md" <<'KEOF'
# Knowledge Index

## Domain Clusters
- **git**: 3 instincts, avg occurrences 15.3
- **security**: 5 instincts, avg occurrences 8.1

## Coverage Gaps
- No instincts for domain: testing

## Last Updated
2026-04-06T10:00:00Z
KEOF
run_dream
EXIT_CODE=$?
REPORT=$(get_report)
if [ "$EXIT_CODE" -eq 0 ] && [ -n "$REPORT" ]; then
  # Check if knowledge index is referenced in the report
  if echo "$REPORT" | grep -qi "knowledge\|karpathy\|coverage\|cluster\|domain"; then
    pass "E14: Knowledge index read and referenced in report"
  else
    pass "E14: Script ran with knowledge index present (no crash)"
  fi
else
  fail "E14: Script crashed or produced no report with knowledge index present (exit=$EXIT_CODE)"
fi
teardown_sandbox

# ─────────────────────────────────────────────────────────
# E15: Performance with 100 instincts < 5 seconds
# ─────────────────────────────────────────────────────────
echo "── E15: Performance benchmark ──"
setup_sandbox
# Generate 100 instincts
INSTINCTS=""
for i in $(seq 1 100); do
  [ -n "$INSTINCTS" ] && INSTINCTS="$INSTINCTS,"
  INSTINCTS="$INSTINCTS{\"id\":\"perf-$i\",\"domain\":\"d$((i%10))\",\"level\":\"confirmed\",\"trigger_pattern\":\"pattern$i\",\"inject\":\"Instinct number $i for performance testing.\",\"occurrences\":$((i*2)),\"added\":\"2026-01-01\"}"
done
write_index "{
  \"version\": \"4.2\",
  \"instincts\": [$INSTINCTS]
}"
START_TIME=$(date +%s)
run_dream
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
REPORT=$(get_report)
if [ "$ELAPSED" -lt 5 ] && [ -n "$REPORT" ]; then
  pass "E15: 100 instincts processed in ${ELAPSED}s (< 5s)"
else
  if [ -z "$REPORT" ]; then
    fail "E15: No report produced for 100 instincts (${ELAPSED}s)"
  else
    fail "E15: Performance too slow: ${ELAPSED}s (limit: 5s)"
  fi
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
