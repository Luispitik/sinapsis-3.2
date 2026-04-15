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

# ── TEST 12: Bash syntax of all core/*.sh files ──
echo ""
echo "[Test Group 6: Regression — bash syntax + projects-registry upsert]"

SYNTAX_BAD=0
for sh_file in "$SCRIPT_DIR/core/"*.sh; do
  if ! bash -n "$sh_file" 2>/dev/null; then
    fail "core/$(basename "$sh_file"): bash syntax invalid"
    SYNTAX_BAD=$((SYNTAX_BAD + 1))
  fi
done
[ "$SYNTAX_BAD" -eq 0 ] && pass "All core/*.sh have valid bash syntax (regression: node -e quoting bug)"

# ── TEST 13: _session-learner.sh upserts canonical _projects.json ──
SANDBOX="$(mktemp -d)/upsert-test"
mkdir -p "$SANDBOX/.claude/skills" "$SANDBOX/.claude/homunculus/projects/testhash000001"
cat > "$SANDBOX/.claude/homunculus/projects/testhash000001/observations.jsonl" << 'EOF'
{"timestamp":"2026-04-15T22:00:00Z","event":"tool_complete","tool":"Bash","session":"s1","project_id":"testhash000001","project_name":"my-test-project","input":"{}"}
{"timestamp":"2026-04-15T22:00:01Z","event":"tool_complete","tool":"Read","session":"s1","project_id":"testhash000001","project_name":"my-test-project","input":"{}"}
{"timestamp":"2026-04-15T22:00:02Z","event":"tool_complete","tool":"Edit","session":"s1","project_id":"testhash000001","project_name":"my-test-project","input":"{}"}
EOF
cat > "$SANDBOX/.claude/skills/_projects.json" << 'EOF'
{"version":"4.1","system":"sinapsis","projects":[]}
EOF
HOME="$SANDBOX" bash "$SCRIPT_DIR/core/_session-learner.sh" >/dev/null 2>&1 || true

if grep -q '"name": "my-test-project"' "$SANDBOX/.claude/skills/_projects.json" 2>/dev/null; then
  pass "_session-learner.sh upserts project entry into _projects.json"
else
  fail "_session-learner.sh did NOT upsert into _projects.json (bug regressed)"
fi

# Idempotency: second run should NOT duplicate
HOME="$SANDBOX" bash "$SCRIPT_DIR/core/_session-learner.sh" >/dev/null 2>&1 || true
COUNT=$(grep -c '"id":' "$SANDBOX/.claude/skills/_projects.json" 2>/dev/null || echo 0)
if [ "$COUNT" -eq 1 ]; then
  pass "_session-learner.sh upsert is idempotent (no duplicates on repeat)"
else
  fail "Upsert duplicated entries (got $COUNT entries, expected 1)"
fi

rm -rf "$(dirname "$SANDBOX")"

# ── TEST 14: End-to-end — observe_v3.py emits cwd → session-learner derives root/remote ──
# Regression guard for Codex finding: session-learner reads lines[i].cwd to run git rev-parse,
# but observe_v3.py was not writing cwd → root/remote remained empty on fresh installs.
SANDBOX_E2E_PARENT="$(mktemp -d)"
SANDBOX="$SANDBOX_E2E_PARENT/e2e"
mkdir -p "$SANDBOX/.claude/skills"
FAKEREPO="$SANDBOX/fakerepo"
mkdir -p "$FAKEREPO"
git -C "$FAKEREPO" init -q
git -C "$FAKEREPO" remote add origin "https://github.com/test/e2e-project.git"

# Seed empty canonical registry so upsert has a target
cat > "$SANDBOX/.claude/skills/_projects.json" << 'EOF'
{"version":"4.1","system":"sinapsis","projects":[]}
EOF

# On Windows/Git Bash, Python + Windows git don't understand POSIX /tmp/... paths.
# Convert to Windows form (C:/...) to match what Claude Code sends on Windows.
if command -v cygpath >/dev/null 2>&1; then
  FAKEREPO_FOR_PAYLOAD=$(cygpath -w "$FAKEREPO" | sed 's|\\|/|g')
else
  FAKEREPO_FOR_PAYLOAD="$FAKEREPO"
fi

# Simulate a real PostToolUse hook payload going through observe.sh
PAYLOAD=$(cat << EOF
{"cwd":"$FAKEREPO_FOR_PAYLOAD","tool_name":"Bash","tool_input":{"command":"ls"},"tool_response":"ok","session_id":"s-e2e"}
EOF
)
# NOTE: On Windows Python prefers HOMEDRIVE+HOMEPATH > USERPROFILE > HOME for ~.
# Clearing HOMEDRIVE/HOMEPATH + setting USERPROFILE forces the sandbox path. Harmless on Linux/macOS.
# Session-learner requires >=3 observations to process the file — invoke observe.sh 3 times.
for _ in 1 2 3; do
  echo "$PAYLOAD" | HOME="$SANDBOX" USERPROFILE="$SANDBOX" HOMEDRIVE="" HOMEPATH="" \
    bash "$SCRIPT_DIR/skills/sinapsis-learning/hooks/observe.sh" post >/dev/null 2>&1 || true
done

# 14a: observation file must contain cwd field
OBS_FILE=$(find "$SANDBOX/.claude/homunculus/projects" -name "observations.jsonl" 2>/dev/null | head -1)
if [ -n "$OBS_FILE" ] && grep -q '"cwd":' "$OBS_FILE" 2>/dev/null; then
  pass "observe_v3.py writes cwd field into observation (fresh install end-to-end)"
else
  fail "observe_v3.py did NOT write cwd field — session-learner cannot derive root/remote"
fi

# 14b + 14c: run session-learner, verify root + remote populated from git rev-parse
HOME="$SANDBOX" USERPROFILE="$SANDBOX" HOMEDRIVE="" HOMEPATH="" \
  bash "$SCRIPT_DIR/core/_session-learner.sh" >/dev/null 2>&1 || true

if grep -q '"remote": "https://github.com/test/e2e-project.git"' "$SANDBOX/.claude/skills/_projects.json" 2>/dev/null; then
  pass "_session-learner.sh derives remote via git rev-parse from observation.cwd"
else
  fail "_session-learner.sh did NOT derive remote — cwd field not wired through"
fi

if grep -q '"root":' "$SANDBOX/.claude/skills/_projects.json" 2>/dev/null && \
   ! grep -q '"root": ""' "$SANDBOX/.claude/skills/_projects.json" 2>/dev/null; then
  pass "_session-learner.sh derives root via git rev-parse from observation.cwd"
else
  fail "_session-learner.sh did NOT derive root — root is empty in registry"
fi

rm -rf "$SANDBOX_E2E_PARENT"

# ── Results ──
echo ""
echo "==============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "==============================="
[ "$FAIL" -gt 0 ] && exit 1
exit 0
