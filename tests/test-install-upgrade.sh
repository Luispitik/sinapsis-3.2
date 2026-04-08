#!/bin/bash
# ============================================================
# TDD Tests: install.sh upgrade safety
# Bug #1, #2, #3 — install.sh must preserve user data on upgrade
# ============================================================

set -e

PASS=0
FAIL=0
TESTS=0

pass() { PASS=$((PASS + 1)); TESTS=$((TESTS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); TESTS=$((TESTS + 1)); echo "  FAIL: $1"; }

SANDBOX=""
cleanup() {
  [ -n "$SANDBOX" ] && rm -rf "$SANDBOX"
}
trap cleanup EXIT

# Create sandbox
SANDBOX=$(mktemp -d)
FAKE_HOME="$SANDBOX/home"
FAKE_CLAUDE="$FAKE_HOME/.claude"
FAKE_SKILLS="$FAKE_CLAUDE/skills"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "=== install.sh Upgrade Safety Tests ==="
echo "Sandbox: $SANDBOX"
echo ""

# ── Helper: simulate fresh install ──
fresh_install() {
  rm -rf "$FAKE_HOME"
  mkdir -p "$FAKE_HOME"
  HOME="$FAKE_HOME" bash "$SCRIPT_DIR/install.sh" > /dev/null 2>&1
}

# ── Helper: simulate upgrade with modified user data ──
upgrade_with_user_data() {
  HOME="$FAKE_HOME" bash "$SCRIPT_DIR/install.sh" > /dev/null 2>&1
}

# ── TEST 1: Fresh install creates _instincts-index.json ──
echo "[Test Group 1: Fresh Install]"
fresh_install

if [ -f "$FAKE_SKILLS/_instincts-index.json" ]; then
  pass "Fresh install creates _instincts-index.json"
else
  fail "Fresh install should create _instincts-index.json"
fi

# ── TEST 2: Fresh install creates _passive-rules.json ──
if [ -f "$FAKE_SKILLS/_passive-rules.json" ]; then
  pass "Fresh install creates _passive-rules.json"
else
  fail "Fresh install should create _passive-rules.json"
fi

# ── TEST 3: Fresh install creates _projects.json ──
if [ -f "$FAKE_SKILLS/_projects.json" ]; then
  pass "Fresh install creates _projects.json"
else
  fail "Fresh install should create _projects.json"
fi

# ── TEST 4: Upgrade preserves custom _instincts-index.json ──
echo ""
echo "[Test Group 2: Upgrade Preserves User Data]"

# Inject custom user data into instincts index
cat > "$FAKE_SKILLS/_instincts-index.json" << 'CUSTOM_INDEX'
{
  "version": "4.1",
  "instincts": [
    {
      "id": "user-custom-instinct-1",
      "domain": "security",
      "level": "confirmed",
      "trigger_pattern": "api.?key|secret",
      "inject": "User's custom security rule learned over 3 months",
      "origin": "learned",
      "added": "2026-01-15",
      "occurrences": 42,
      "first_triggered": "2026-01-20T10:00:00Z",
      "last_triggered": "2026-04-07T15:30:00Z"
    },
    {
      "id": "user-custom-instinct-2",
      "domain": "nextjs",
      "level": "permanent",
      "trigger_pattern": "next\\.config|middleware",
      "inject": "Always use edge runtime for middleware",
      "origin": "manual",
      "added": "2026-02-01",
      "occurrences": 87
    }
  ],
  "archived": [
    {
      "id": "archived-old-rule",
      "domain": "docker",
      "level": "draft",
      "inject": "Old docker rule"
    }
  ]
}
CUSTOM_INDEX

# Run upgrade
upgrade_with_user_data

# Check that custom data survived
if grep -q "user-custom-instinct-1" "$FAKE_SKILLS/_instincts-index.json" 2>/dev/null; then
  pass "Upgrade preserves custom instincts (instinct-1)"
else
  fail "Upgrade DESTROYED custom instincts (Bug #1)"
fi

if grep -q "user-custom-instinct-2" "$FAKE_SKILLS/_instincts-index.json" 2>/dev/null; then
  pass "Upgrade preserves custom instincts (instinct-2)"
else
  fail "Upgrade DESTROYED custom instincts (Bug #1)"
fi

if grep -q "occurrences.*42" "$FAKE_SKILLS/_instincts-index.json" 2>/dev/null; then
  pass "Upgrade preserves occurrence counters"
else
  fail "Upgrade DESTROYED occurrence tracking data"
fi

if grep -q "archived-old-rule" "$FAKE_SKILLS/_instincts-index.json" 2>/dev/null; then
  pass "Upgrade preserves archived instincts"
else
  fail "Upgrade DESTROYED archived instincts"
fi

# ── TEST 5: Upgrade preserves custom _passive-rules.json ──
cat > "$FAKE_SKILLS/_passive-rules.json" << 'CUSTOM_RULES'
{
  "rules": [
    {
      "id": "custom-user-rule",
      "trigger": "deploy|vercel",
      "inject": "User's custom deploy rule",
      "severity": "high",
      "category": "workflow",
      "tokens": 25,
      "fireCount": 15,
      "lastFired": "2026-04-07T12:00:00Z"
    }
  ]
}
CUSTOM_RULES

upgrade_with_user_data

if grep -q "custom-user-rule" "$FAKE_SKILLS/_passive-rules.json" 2>/dev/null; then
  pass "Upgrade preserves custom passive rules"
else
  fail "Upgrade DESTROYED custom passive rules (Bug #2)"
fi

# ── TEST 6: Upgrade preserves custom _projects.json ──
cat > "$FAKE_SKILLS/_projects.json" << 'CUSTOM_PROJECTS'
{
  "abc123def456": {
    "name": "my-saas-app",
    "root": "/home/user/projects/my-saas",
    "registered": "2026-03-01"
  },
  "789ghi012jkl": {
    "name": "client-portal",
    "root": "/home/user/projects/client",
    "registered": "2026-02-15"
  }
}
CUSTOM_PROJECTS

upgrade_with_user_data

if grep -q "my-saas-app" "$FAKE_SKILLS/_projects.json" 2>/dev/null; then
  pass "Upgrade preserves project registry"
else
  fail "Upgrade DESTROYED project registry (Bug #3)"
fi

if grep -q "client-portal" "$FAKE_SKILLS/_projects.json" 2>/dev/null; then
  pass "Upgrade preserves all registered projects"
else
  fail "Upgrade DESTROYED registered projects"
fi

# ── TEST 7: Upgrade still preserves _operator-state.json (existing behavior) ──
echo ""
echo "[Test Group 3: Existing Preservations Still Work]"

cat > "$FAKE_SKILLS/_operator-state.json" << 'CUSTOM_STATE'
{
  "operator": { "name": "TestUser", "brands": ["testbrand"] },
  "needsOnboarding": false,
  "strategicDecisions": [{"id": "d999", "decision": "Custom decision"}]
}
CUSTOM_STATE

upgrade_with_user_data

if grep -q "TestUser" "$FAKE_SKILLS/_operator-state.json" 2>/dev/null; then
  pass "Upgrade preserves operator state (existing behavior)"
else
  fail "Upgrade broke operator state preservation"
fi

# ── TEST 8: Upgrade still updates hook scripts ──
if [ -f "$FAKE_SKILLS/_instinct-activator.sh" ]; then
  pass "Upgrade installs hook scripts"
else
  fail "Upgrade should install hook scripts"
fi

# ── TEST 9: Upgrade still updates skills ──
if [ -d "$FAKE_SKILLS/skill-router" ]; then
  pass "Upgrade installs skills"
else
  fail "Upgrade should install skills"
fi

# ── TEST 10: Upgrade creates backup ──
echo ""
echo "[Test Group 4: Backup on Upgrade]"

BACKUP_DIRS=$(find "$FAKE_CLAUDE" -maxdepth 1 -name "_backup_*" -type d 2>/dev/null | wc -l)
if [ "$BACKUP_DIRS" -gt 0 ]; then
  pass "Upgrade creates backup directory"
else
  fail "Upgrade should create backup"
fi

# ── TEST 11: --force-update flag overwrites data files ──
echo ""
echo "[Test Group 5: Force Update]"

# Add custom data
cat > "$FAKE_SKILLS/_instincts-index.json" << 'EOF'
{"version":"4.1","instincts":[{"id":"to-be-overwritten","level":"confirmed"}],"archived":[]}
EOF

# Run with --force-update (this test will initially fail — TDD red phase)
HOME="$FAKE_HOME" bash "$SCRIPT_DIR/install.sh" --force-update > /dev/null 2>&1 || true

if grep -q "to-be-overwritten" "$FAKE_SKILLS/_instincts-index.json" 2>/dev/null; then
  fail "--force-update should overwrite data files"
else
  pass "--force-update overwrites data files"
fi

# ── Results ──
echo ""
echo "==============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "==============================="
[ "$FAIL" -gt 0 ] && exit 1
exit 0
