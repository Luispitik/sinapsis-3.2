#!/bin/bash
# Sinapsis Observer - v4.1
# Writes one JSONL line per tool use to observations.jsonl
# Requires: python3
# Called by settings.json hooks as:
#   PreToolUse:  bash ~/.claude/skills/sinapsis-learning/hooks/observe.sh pre
#   PostToolUse: bash ~/.claude/skills/sinapsis-learning/hooks/observe.sh post

HOOK_PHASE="${1:-post}"

# Read stdin
INPUT_JSON=$(cat)
[ -z "$INPUT_JSON" ] && exit 0

# Skip if disabled
[ -f "$HOME/.claude/homunculus/disabled" ] && exit 0

# Skip non-interactive entrypoints
case "${CLAUDE_CODE_ENTRYPOINT:-cli}" in
  cli|sdk|api|claude-desktop|"") ;;
  *) exit 0 ;;
esac

[ "${ECC_HOOK_PROFILE:-standard}" = "minimal" ] && exit 0
[ "${ECC_SKIP_OBSERVE:-0}" = "1" ] && exit 0

# Find Python
PYTHON_CMD=""
if command -v python3 >/dev/null 2>&1; then
  PYTHON_CMD="python3"
elif command -v python >/dev/null 2>&1 && python --version 2>&1 | grep -q "Python 3"; then
  PYTHON_CMD="python"
fi
[ -z "$PYTHON_CMD" ] && exit 0

# Run the observer
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
echo "$INPUT_JSON" | "$PYTHON_CMD" "$SCRIPT_DIR/observe_v3.py" "$HOOK_PHASE"

exit 0
