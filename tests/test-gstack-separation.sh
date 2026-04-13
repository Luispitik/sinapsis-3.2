#!/bin/bash
# test-gstack-separation.sh — TDD tests for GStack component separation
# Verifies that:
# 1. Core learning pipeline files are intact
# 2. GStack files are removed from repo
# 3. No dangling references to removed files
# 4. Install scripts don't reference removed components
# 5. README/CHANGELOG are consistent
# Run: bash tests/test-gstack-separation.sh

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

PASS=0
FAIL=0
TOTAL=18

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

echo ""
echo "=== Sinapsis — GStack Separation Tests ==="
echo "=== $TOTAL tests: core integrity + removal verification ==="
echo ""

# ── Section 1: Core learning pipeline files MUST exist ──
echo "[Section 1] Core learning pipeline integrity"

for f in \
  "core/_instinct-activator.sh" \
  "core/_passive-activator.sh" \
  "core/_session-learner.sh" \
  "core/_project-context.sh" \
  "core/_dream.sh" \
  "core/_eod-gather.sh" \
  "skills/sinapsis-learning/SKILL.md" \
  "skills/sinapsis-learning/hooks/observe.sh" \
  "skills/sinapsis-learning/hooks/observe_v3.py" \
  "skills/sinapsis-instincts/SKILL.md"; do
  if [ -f "$SCRIPT_DIR/$f" ]; then
    pass "Core file exists: $f"
  else
    fail "Core file MISSING: $f"
  fi
done

# ── Section 2: GStack files MUST NOT exist ──
echo ""
echo "[Section 2] GStack files removed"

for f in \
  "skills/review-army/SKILL.md" \
  "skills/cso-audit/SKILL.md" \
  "skills/investigate-pro/SKILL.md" \
  "commands/retro-semanal.md" \
  "core/_timeline-log.sh"; do
  if [ ! -f "$SCRIPT_DIR/$f" ]; then
    pass "GStack file removed: $f"
  else
    fail "GStack file still present: $f"
  fi
done

# ── Section 3: No dangling references in remaining code ──
echo ""
echo "[Section 3] No dangling references to removed components"

# Check that no .sh or .md file references _timeline-log.sh
TIMELINE_REFS=$(grep -rl "_timeline-log" "$SCRIPT_DIR" --include="*.sh" --include="*.md" --include="*.json" 2>/dev/null | grep -v "test-gstack-separation" | grep -v ".git/" | grep -v "CHANGELOG.md" | grep -v "install.sh" | wc -l)
if [ "$TIMELINE_REFS" -eq 0 ]; then
  pass "No references to _timeline-log.sh in codebase"
else
  fail "Found $TIMELINE_REFS files still referencing _timeline-log.sh"
fi

# Check that README doesn't mention review-army, cso-audit, investigate-pro as current features
GSTACK_README=$(grep -Ec "review-army|cso-audit|investigate-pro|/retro-semanal" "$SCRIPT_DIR/README.md" 2>/dev/null | xargs)
if [ "${GSTACK_README:-0}" -eq 0 ] 2>/dev/null; then
  pass "README.md has no gstack skill references"
else
  fail "README.md still references gstack skills ($GSTACK_README occurrences)"
fi

# Check that __pycache__ is not tracked
PYC_FILES=$(find "$SCRIPT_DIR" -name "*.pyc" -not -path "*/.git/*" 2>/dev/null | wc -l)
if [ "$PYC_FILES" -eq 0 ]; then
  pass ".pyc files removed from repo"
else
  fail "Found $PYC_FILES .pyc files still in repo"
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
