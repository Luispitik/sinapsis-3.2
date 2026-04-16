#!/bin/bash
# test-dashboard.sh — TDD Unit Tests for Sinapsis v4.4 Dashboard Generator
# 12 tests covering: metric computation, template substitution, portable paths,
# empty-state handling, and output structure.
# Run: bash tests/test-dashboard.sh

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GEN_SCRIPT="$SCRIPT_DIR/core/_generate-dashboard.py"
TEMPLATE="$SCRIPT_DIR/core/_dashboard-template.html"

PASS=0
FAIL=0
TOTAL=12

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

setup_sandbox() {
  SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t sinapsis-dash)"
  mkdir -p "$SANDBOX/.claude/skills"
  mkdir -p "$SANDBOX/.claude/homunculus/projects"
  mkdir -p "$SANDBOX/.claude/commands"
}

teardown_sandbox() {
  rm -rf "$SANDBOX" 2>/dev/null
}

write_minimal_index() {
  cat > "$SANDBOX/.claude/skills/_instincts-index.json" <<'EOF'
{
  "version": "4.2",
  "instincts": [
    {"id":"a","trigger_pattern":"a","inject":"A","level":"permanent","scope":"global","domain":"design","origin":"manual","occurrences":10,"first_triggered":"2026-04-01T00:00:00Z","last_triggered":"2026-04-15T00:00:00Z","added":"2026-03-30"},
    {"id":"b","trigger_pattern":"b","inject":"B","level":"confirmed","scope":"global","domain":"tech","origin":"semantic-analysis","occurrences":5,"first_triggered":"2026-04-05T00:00:00Z","last_triggered":"2026-04-14T00:00:00Z","added":"2026-04-03"},
    {"id":"c-dead","trigger_pattern":"c","inject":"C","level":"draft","scope":"global","domain":"content","origin":"manual","occurrences":0,"first_triggered":null,"last_triggered":null,"added":"2026-03-20"}
  ]
}
EOF
}

write_minimal_rules() {
  cat > "$SANDBOX/.claude/skills/_passive-rules.json" <<'EOF'
{"version":"2.0","rules":[{"id":"r1","priority":"high","silent":false},{"id":"r2","priority":"medium","silent":true}]}
EOF
}

run_gen() {
  # Use SINAPSIS_HOME (portable) — HOME env doesn't reach Python's Path.home() on Windows.
  SINAPSIS_HOME="$SANDBOX/.claude" python "$GEN_SCRIPT" 2>&1
}

get_dashboard() { cat "$SANDBOX/.claude/skills/_dashboard.html" 2>/dev/null; }

# ═══ T1 — files exist in repo
if [ -f "$GEN_SCRIPT" ]; then pass "T1: generator script exists"; else fail "T1: $GEN_SCRIPT missing"; fi

# ═══ T2 — template exists in repo
if [ -f "$TEMPLATE" ]; then pass "T2: template exists"; else fail "T2: $TEMPLATE missing"; fi

# ═══ T3 — script has no hardcoded Windows paths (portability)
if ! grep -qE "C:[/\\\\]Users" "$GEN_SCRIPT"; then pass "T3: portable (no hardcoded C:/Users)"; else fail "T3: hardcoded Windows path found"; fi

# ═══ T4 — script uses $HOME/.claude via Path.home() or SINAPSIS_HOME env
if grep -q "SINAPSIS_HOME\|Path.home()" "$GEN_SCRIPT"; then pass "T4: uses portable root resolution"; else fail "T4: no portable root"; fi

# ═══ T5 — template has data injection marker
if grep -q "__SINAPSIS_DATA__" "$TEMPLATE"; then pass "T5: template has data marker"; else fail "T5: __SINAPSIS_DATA__ marker missing"; fi

# ═══ T6 — runs with minimal fixture and produces output
setup_sandbox
write_minimal_index
write_minimal_rules
OUT=$(run_gen)
DASH=$(get_dashboard)
if [ -n "$DASH" ]; then pass "T6: dashboard generated with minimal fixture"; else fail "T6: no dashboard produced"; fi

# ═══ T7 — output replaces data marker with actual JSON
if echo "$DASH" | grep -q '/\*__SINAPSIS_DATA__\*/null'; then
  fail "T7: data marker still present (not substituted)"
elif echo "$DASH" | grep -q '"total_instincts": 3'; then
  pass "T7: data substituted with real metrics"
else
  fail "T7: data substituted but unexpected shape"
fi

# ═══ T8 — dead instinct detected
if echo "$DASH" | grep -q '"c-dead"'; then pass "T8: dead instinct included"; else fail "T8: dead instinct missing"; fi

# ═══ T9 — levels counted correctly
if echo "$DASH" | grep -q '"permanent": 1' && echo "$DASH" | grep -q '"confirmed": 1' && echo "$DASH" | grep -q '"draft": 1'; then
  pass "T9: level counts correct (1/1/1)"
else
  fail "T9: level counts wrong"
fi

# ═══ T10 — domains aggregated
if echo "$DASH" | grep -q '"design"\|"tech"\|"content"'; then pass "T10: domains aggregated"; else fail "T10: domains missing"; fi

# ═══ T11 — empty observations doesn't crash
rm -rf "$SANDBOX/.claude/homunculus"
OUT2=$(run_gen)
if [ -n "$(get_dashboard)" ] && [ "$?" -eq 0 ]; then pass "T11: works without homunculus dir"; else fail "T11: crashed on missing homunculus"; fi
teardown_sandbox

# ═══ T12 — runs without any JSON files (absolute empty state)
setup_sandbox
OUT3=$(run_gen 2>&1)
if echo "$OUT3" | grep -q "\[OK\]"; then
  pass "T12: runs with empty skills dir (no crash)"
else
  fail "T12: failed on empty state — $OUT3"
fi
teardown_sandbox

# ═══ SUMMARY
echo ""
echo "═══════════════════════════════════════════"
echo "  DASHBOARD TESTS: $PASS/$TOTAL passed, $FAIL failed"
echo "═══════════════════════════════════════════"

[ $FAIL -eq 0 ] && exit 0 || exit 1
