#!/usr/bin/env bash
set -euo pipefail
POLL_INTERVAL="${TL_POLL_INTERVAL:-30}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# TL_MODEL is required
if [ -z "${TL_MODEL:-}" ]; then
  echo "Error: TL_MODEL env var is not set."
  echo "Usage: TL_MODEL=<model-name> bash run-tl-loop.sh"
  echo "Example: TL_MODEL=claude-sonnet-4-5 bash scripts/run-tl-loop.sh"
  exit 1
fi

echo "TL loop starting. Model: $TL_MODEL. Poll interval: ${POLL_INTERVAL}s"
echo "Press Ctrl+C to stop."

while true; do
  # Check for TL-relevant work: features needing review or PRs ready for approval
  # Use --label-any (not --status open) so in_progress tasks are also found
  WORK=$(cd "$REPO_DIR" && BD_ACTOR="TL" bd list --label-any needs-tl-review pr-ready --json 2>/dev/null || echo "[]")
  TL_WORK=$([ "$WORK" != "[]" ] && [ -n "$WORK" ] && echo "yes" || echo "")
  if [ -n "$TL_WORK" ]; then
    echo "[$(date '+%H:%M:%S')] TL work found. Invoking opencode..."
    cd "$REPO_DIR" && AGENT_LOOP_MODE=tl opencode run --model "$TL_MODEL" \
      "You are the Tech Lead. Load the tech-lead skill from .opencode/skills/tech-lead/SKILL.md. Check beads for work labelled needs-tl-review or pr-ready and process it. When all available work is done, exit."
    echo "[$(date '+%H:%M:%S')] opencode session complete."
  else
    echo "[$(date '+%H:%M:%S')] No TL work found. Sleeping ${POLL_INTERVAL}s..."
  fi
  sleep "$POLL_INTERVAL"
done
