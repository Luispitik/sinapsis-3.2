#!/bin/bash
# test-v45-opus47.sh — TDD tests for Sinapsis v4.5 (Opus 4.7 integration)
# 6 features: cache-stable ordering, PreCompact hook, raised caps, settings wiring
# Run: bash tests/test-v45-opus47.sh

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ACTIVATOR="$SCRIPT_DIR/core/_instinct-activator.sh"
LEARNER="$SCRIPT_DIR/core/_session-learner.sh"
PRECOMPACT="$SCRIPT_DIR/core/_precompact-guard.sh"
SETTINGS="$SCRIPT_DIR/core/settings.template.json"

PASS=0
FAIL=0
TOTAL=11

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

setup_sandbox() {
  SANDBOX="$(mktemp -d)"
  mkdir -p "$SANDBOX/.claude/skills"
}

teardown_sandbox() {
  rm -rf "$SANDBOX" 2>/dev/null
}

echo ""
echo "=== Sinapsis v4.5 Opus 4.7 Integration Tests ==="
echo "=== $TOTAL tests: cache stability, PreCompact, raised caps ==="
echo ""

# ── Section 1: Cache-stable ordering (P1) ──
echo "[Section 1] Deterministic ordering for prompt cache hits"

# T1: activator has id-based tiebreaker in the sort
if grep -q "localeCompare\|a\.id.*b\.id\|tiebreaker" "$ACTIVATOR" 2>/dev/null; then
  pass "T1: Activator has deterministic id tiebreaker"
else
  fail "T1: Activator must have id-based tiebreaker for cache stability"
fi

# T2: functional — two runs with identical input and shuffled index produce identical output
setup_sandbox

# Build an index with 4 instincts of same level + occurrences — tiebreaker must pick alphabetical
cat > "$SANDBOX/.claude/skills/_instincts-index.json" << 'EOFIDX'
{
  "version": "4.1",
  "instincts": [
    {"id":"zebra","domain":"general","level":"confirmed","trigger_pattern":"Edit","inject":"Z rule","occurrences":5,"first_triggered":"2026-04-01","last_triggered":"2026-04-20"},
    {"id":"alpha","domain":"security","level":"confirmed","trigger_pattern":"Edit","inject":"A rule","occurrences":5,"first_triggered":"2026-04-01","last_triggered":"2026-04-20"},
    {"id":"mike","domain":"git","level":"confirmed","trigger_pattern":"Edit","inject":"M rule","occurrences":5,"first_triggered":"2026-04-01","last_triggered":"2026-04-20"}
  ],
  "archived": []
}
EOFIDX

INPUT='{"tool_name":"Edit","tool_input":{"file_path":"x.js"}}'
OUT1=$(echo "$INPUT" | HOME="$SANDBOX" bash "$ACTIVATOR" 2>/dev/null)

# Shuffle the on-disk order and rerun — result must be byte-identical
cat > "$SANDBOX/.claude/skills/_instincts-index.json" << 'EOFIDX2'
{
  "version": "4.1",
  "instincts": [
    {"id":"mike","domain":"git","level":"confirmed","trigger_pattern":"Edit","inject":"M rule","occurrences":5,"first_triggered":"2026-04-01","last_triggered":"2026-04-20"},
    {"id":"zebra","domain":"general","level":"confirmed","trigger_pattern":"Edit","inject":"Z rule","occurrences":5,"first_triggered":"2026-04-01","last_triggered":"2026-04-20"},
    {"id":"alpha","domain":"security","level":"confirmed","trigger_pattern":"Edit","inject":"A rule","occurrences":5,"first_triggered":"2026-04-01","last_triggered":"2026-04-20"}
  ],
  "archived": []
}
EOFIDX2

OUT2=$(echo "$INPUT" | HOME="$SANDBOX" bash "$ACTIVATOR" 2>/dev/null)

if [ -n "$OUT1" ] && [ "$OUT1" = "$OUT2" ]; then
  pass "T2: Shuffled index produces byte-identical inject (cache-safe)"
else
  fail "T2: Output differs after index shuffle — cache will miss. OUT1='$OUT1' OUT2='$OUT2'"
fi

# T3: when tied on level+occurrences, alpha comes before mike comes before zebra
if echo "$OUT1" | grep -q "A rule.*M rule.*Z rule" 2>/dev/null; then
  pass "T3: Alphabetical tiebreaker applied (A < M < Z)"
else
  fail "T3: Expected alpha→mike→zebra order in output, got: '$OUT1'"
fi

teardown_sandbox

# ── Section 2: PreCompact hook (P2) ──
echo ""
echo "[Section 2] PreCompact guardrail hook"

if [ -f "$PRECOMPACT" ]; then
  pass "T4: _precompact-guard.sh exists"
else
  fail "T4: _precompact-guard.sh must exist in core/"
fi

if [ -x "$PRECOMPACT" ]; then
  pass "T5: _precompact-guard.sh is executable"
else
  fail "T5: _precompact-guard.sh must be executable"
fi

# T6: settings.template.json registers PreCompact
if grep -q "PreCompact" "$SETTINGS" 2>/dev/null; then
  pass "T6: settings.template.json declares PreCompact hook"
else
  fail "T6: PreCompact hook must be in settings.template.json"
fi

# T7: PreCompact points to precompact-guard.sh
if grep -q "_precompact-guard\.sh" "$SETTINGS" 2>/dev/null; then
  pass "T7: PreCompact hook wires to _precompact-guard.sh"
else
  fail "T7: PreCompact hook must call _precompact-guard.sh"
fi

# T8: install.sh copies the new hook
if grep -q "_precompact-guard\.sh" "$SCRIPT_DIR/install.sh" 2>/dev/null; then
  pass "T8: install.sh copies _precompact-guard.sh"
else
  fail "T8: install.sh must copy _precompact-guard.sh"
fi

# ── Section 3: Raised caps (P3) ──
echo ""
echo "[Section 3] Caps raised for Opus 4.7 1M context"

# T9: TOKEN_BUDGET >= 4000 in activator
if grep -qE "TOKEN_BUDGET\s*=\s*[4-9][0-9]{3}" "$ACTIVATOR" 2>/dev/null; then
  pass "T9: TOKEN_BUDGET >= 4000 in activator"
else
  fail "T9: TOKEN_BUDGET should be raised to >=4000"
fi

# T10: MAX_INSTINCTS_INJECTED present and >= 6
if grep -qE "MAX_INSTINCTS_INJECTED\s*=\s*[6-9]|slice\(0,\s*[6-9]\)" "$ACTIVATOR" 2>/dev/null; then
  pass "T10: MAX_INSTINCTS_INJECTED raised to >=6"
else
  fail "T10: Top-N slice should be raised to >=6"
fi

# T11: session-learner reads >= 5000 obs lines
if grep -qE "slice\(-[5-9][0-9]{3}\)|slice\(-[1-9][0-9]{4}\)" "$LEARNER" 2>/dev/null; then
  pass "T11: session-learner reads >=5000 observation lines"
else
  fail "T11: OBS_READ_LINES cap should be raised to >=5000"
fi

# ── Summary ──
echo ""
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
if [ "$FAIL" -eq 0 ]; then
  echo "ALL TESTS PASSED"
  exit 0
else
  echo "SOME TESTS FAILED"
  exit 1
fi
