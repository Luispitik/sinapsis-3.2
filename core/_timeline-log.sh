#!/usr/bin/env bash
# _timeline-log.sh — Append skill/event entries to session timeline JSONL
# Usage: bash ~/.claude/skills/_timeline-log.sh <skill> <event> [key=value ...]
# Example: bash ~/.claude/skills/_timeline-log.sh review-army started branch=feat/auth
# Example: bash ~/.claude/skills/_timeline-log.sh review-army completed findings=3 quality_score=8.5
#
# Sinapsis v4.4 — gstack-inspired session timeline

set -euo pipefail

TIMELINE_FILE="${HOME}/.claude/skills/_session-timeline.jsonl"
SKILL="${1:-unknown}"
EVENT="${2:-unknown}"
shift 2 2>/dev/null || true

# Build timestamp
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ")

# Build JSON entry
JSON="{\"ts\":\"${TS}\",\"skill\":\"${SKILL}\",\"event\":\"${EVENT}\""

# Add optional key=value pairs
for arg in "$@"; do
  key="${arg%%=*}"
  val="${arg#*=}"
  # Try to detect numeric values
  if [[ "$val" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    JSON="${JSON},\"${key}\":${val}"
  else
    # Escape quotes in string values
    val="${val//\\/\\\\}"
    val="${val//\"/\\\"}"
    JSON="${JSON},\"${key}\":\"${val}\""
  fi
done

JSON="${JSON}}"

# Atomic append with file locking (fcntl on Linux/Mac, fallback on Windows)
if command -v flock >/dev/null 2>&1; then
  (
    flock -w 5 200
    printf '%s\n' "$JSON" >> "$TIMELINE_FILE"
  ) 200>"${TIMELINE_FILE}.lock"
  rm -f "${TIMELINE_FILE}.lock"
else
  # Windows/Git Bash fallback — no flock available
  printf '%s\n' "$JSON" >> "$TIMELINE_FILE"
fi
