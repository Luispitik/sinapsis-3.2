#!/bin/bash
# PreCompact Guard - Sinapsis v4.5
# PreCompact hook: fires right before Claude Code compacts the context in a long-running
# session. Without this, any tool events observed after the previous Stop and before the
# compaction happens can be dropped when compaction rewrites the transcript.
#
# Strategy: re-invoke _session-learner.sh (idempotent, gated by .last-learn) so any fresh
# observations are flushed to proposals before context is lost. Session-learner already
# handles its own locking and skips re-processing observations older than .last-learn.
#
# Runs sync with short timeout so compaction is not noticeably delayed.

if [ "${SINAPSIS_DEBUG:-}" = "1" ]; then
  exec 2>>"$HOME/.claude/skills/_sinapsis-debug.log"
fi

LEARNER="$HOME/.claude/skills/_session-learner.sh"
LOG="$HOME/.claude/skills/_precompact.log"

[ ! -x "$LEARNER" ] && exit 0

now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "$now | precompact | invoking learner" >> "$LOG" 2>/dev/null

# Fire-and-forget: run the learner but bound its time so we never block the harness.
# If learner is already running (Stop fired in parallel), the advisory lock inside it
# serialises writes to _projects.json.
timeout 8 bash "$LEARNER" </dev/null >/dev/null 2>&1 &

exit 0
