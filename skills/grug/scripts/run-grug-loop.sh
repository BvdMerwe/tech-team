#!/usr/bin/env bash
# Grug loop - polls beads for pr-ready work, invokes opencode to review.
# Uses shared agent-loop.lib.sh for common loop logic.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || (cd "$SCRIPT_DIR/../../.." && pwd))"

GRUG_MODEL="${GRUG_MODEL:-}"
if [ -z "$GRUG_MODEL" ]; then
  echo "Error: GRUG_MODEL env var is not set."
  echo "Usage: GRUG_MODEL=<model-name> bash .trogteam/run-grug-loop.sh"
  exit 1
fi

export AGENT_NAME="Grug"
export AGENT_MODEL="$GRUG_MODEL"
export AGENT_LABEL="pr-ready"
export AGENT_LOOP_MODE="grug"
export POLL_INTERVAL="${GRUG_POLL_INTERVAL:-30}"

# Source shared library
source "$(dirname "$0")/agent-loop.lib.sh"

AGENT_PROMPT="You are Grug. Load the grug skill. Also load the caveman skill. Check beads for work labelled pr-ready and review it for complexity and obvious mistakes. Approve or send back. When all work reviewed, exit."

main() {
  acquire_lock || exit 1
  trap cleanup EXIT SIGTERM SIGINT

  log "$AGENT_NAME loop starting. Model: $AGENT_MODEL. Poll interval: ${POLL_INTERVAL}s"
  log "Press Ctrl+C to stop."

  while true; do
    TASK_INFO=$(get_next_task)
    if [ -n "$TASK_INFO" ]; then
      TASK_ID=$(echo "$TASK_INFO" | cut -d'|' -f1)
      TASK_TITLE=$(echo "$TASK_INFO" | cut -d'|' -f2-)

      log "Found work: $TASK_ID - $TASK_TITLE"
      WORK_DIR="$REPO_DIR"

      run_agent "$TASK_ID" "$TASK_TITLE" "$AGENT_PROMPT"
    else
      log "No $AGENT_NAME work found. Sleeping ${POLL_INTERVAL}s..."
      sleep "$POLL_INTERVAL"
    fi
  done
}

main "$@"