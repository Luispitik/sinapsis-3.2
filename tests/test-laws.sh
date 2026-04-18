#!/bin/bash
# test-laws.sh — TDD Unit Tests for Sinapsis laws injector (v4.5)
# Covers: frontmatter parse, SESSION_PREFETCH_LAWS output, rotation,
#         last_injected atomic update, MAX_LAWS cap, token budget, malformed handling.
# Run: bash tests/test-laws.sh

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INJECTOR="$SCRIPT_DIR/core/_laws-injector.sh"
SEEDS_REPO="$SCRIPT_DIR/seeds/laws"

PASS=0
FAIL=0
TOTAL=10

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

setup_sandbox() {
  SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t sinapsis-laws)"
  mkdir -p "$SANDBOX/.claude/skills/_laws"
  export HOME="$SANDBOX"
}

teardown_sandbox() {
  unset HOME
  rm -rf "$SANDBOX" 2>/dev/null
}

seed_laws() {
  cp "$SEEDS_REPO"/*.txt "$SANDBOX/.claude/skills/_laws/" 2>/dev/null
}

run_injector() {
  bash "$INJECTOR" 2>/dev/null
}

# ─ Test 1: injector exists ─
echo "Test 1: injector file present"
if [ -f "$INJECTOR" ]; then pass "injector file present"; else fail "injector missing: $INJECTOR"; fi

# ─ Test 2: seeds directory populated ─
echo "Test 2: seed laws present"
SEED_COUNT=$(find "$SEEDS_REPO" -name "*.txt" -type f 2>/dev/null | wc -l)
SEED_COUNT=$(echo "$SEED_COUNT" | tr -d ' ')
if [ "$SEED_COUNT" -ge 5 ]; then pass "$SEED_COUNT seed laws found"; else fail "expected >=5, got $SEED_COUNT"; fi

# ─ Test 3: missing dir → silent exit ─
echo "Test 3: missing _laws dir → no output"
setup_sandbox
rm -rf "$SANDBOX/.claude/skills/_laws"
OUT=$(run_injector)
if [ -z "$OUT" ]; then pass "silent exit when dir absent"; else fail "unexpected output: $OUT"; fi
teardown_sandbox

# ─ Test 4: empty dir → silent exit ─
echo "Test 4: empty _laws dir → no output"
setup_sandbox
OUT=$(run_injector)
if [ -z "$OUT" ]; then pass "silent exit when dir empty"; else fail "unexpected output: $OUT"; fi
teardown_sandbox

# ─ Test 5: valid laws emit SESSION_PREFETCH_LAWS lines ─
echo "Test 5: emits SESSION_PREFETCH_LAWS lines"
setup_sandbox
seed_laws
OUT=$(run_injector)
LINES=$(echo "$OUT" | grep -c "^SESSION_PREFETCH_LAWS:")
if [ "$LINES" -eq "$SEED_COUNT" ]; then pass "emitted $LINES lines"; else fail "expected $SEED_COUNT lines, got $LINES"; fi
teardown_sandbox

# ─ Test 6: MAX_LAWS cap (10) ─
echo "Test 6: MAX_LAWS cap enforced"
setup_sandbox
# Create 15 dummy law files
for i in $(seq 1 15); do
  cat > "$SANDBOX/.claude/skills/_laws/law-$i.txt" <<EOF
---
id: law-$i
source_instinct: null
source: test
created: 2026-04-18
last_injected: 1970-01-01T00:00:00Z
---
Short law number $i.
EOF
done
OUT=$(run_injector)
LINES=$(echo "$OUT" | grep -c "^SESSION_PREFETCH_LAWS:")
if [ "$LINES" -le 10 ]; then pass "cap respected: $LINES <= 10"; else fail "cap exceeded: $LINES > 10"; fi
teardown_sandbox

# ─ Test 7: last_injected updated after run ─
echo "Test 7: last_injected atomically updated"
setup_sandbox
seed_laws
run_injector > /dev/null
STALE=$(grep -l "1970-01-01T00:00:00Z" "$SANDBOX/.claude/skills/_laws/"*.txt 2>/dev/null | wc -l)
STALE=$(echo "$STALE" | tr -d ' ')
if [ "$STALE" = "0" ]; then pass "all last_injected updated"; else fail "$STALE files still stale"; fi
teardown_sandbox

# ─ Test 8: rotation — oldest picked first ─
echo "Test 8: rotation by last_injected ASC"
setup_sandbox
cat > "$SANDBOX/.claude/skills/_laws/law-a.txt" <<'EOF'
---
id: law-a
source_instinct: null
source: test
created: 2026-04-18
last_injected: 2026-04-17T10:00:00Z
---
Law A — middle timestamp.
EOF
cat > "$SANDBOX/.claude/skills/_laws/law-b.txt" <<'EOF'
---
id: law-b
source_instinct: null
source: test
created: 2026-04-18
last_injected: 2020-01-01T00:00:00Z
---
Law B — oldest timestamp.
EOF
cat > "$SANDBOX/.claude/skills/_laws/law-c.txt" <<'EOF'
---
id: law-c
source_instinct: null
source: test
created: 2026-04-18
last_injected: 2026-04-18T10:00:00Z
---
Law C — newest timestamp.
EOF
OUT=$(run_injector)
FIRST=$(echo "$OUT" | head -1)
if echo "$FIRST" | grep -q "Law B"; then pass "oldest emitted first"; else fail "rotation broken, first line was: $FIRST"; fi
teardown_sandbox

# ─ Test 9: malformed file → skipped, not crash ─
echo "Test 9: malformed file does not crash"
setup_sandbox
cat > "$SANDBOX/.claude/skills/_laws/broken.txt" <<'EOF'
no frontmatter at all, just text
EOF
cat > "$SANDBOX/.claude/skills/_laws/good.txt" <<'EOF'
---
id: good
source_instinct: null
source: test
created: 2026-04-18
last_injected: 1970-01-01T00:00:00Z
---
Good law.
EOF
OUT=$(run_injector)
if echo "$OUT" | grep -q "Good law"; then pass "good law emitted, broken skipped"; else fail "malformed file broke injector"; fi
teardown_sandbox

# ─ Test 10: text field collapses multi-line whitespace ─
echo "Test 10: whitespace normalization in text"
setup_sandbox
cat > "$SANDBOX/.claude/skills/_laws/multiline.txt" <<'EOF'
---
id: multiline
source_instinct: null
source: test
created: 2026-04-18
last_injected: 1970-01-01T00:00:00Z
---
Line one
  continued on line two
EOF
OUT=$(run_injector)
if echo "$OUT" | grep -q "Line one continued on line two"; then pass "whitespace normalized"; else fail "normalization failed: $OUT"; fi
teardown_sandbox

# Summary
echo ""
echo "═══════════════════════════════════════"
echo "  Results: $PASS passed, $FAIL failed (of $TOTAL)"
echo "═══════════════════════════════════════"
if [ "$FAIL" -gt 0 ]; then exit 1; fi
exit 0
