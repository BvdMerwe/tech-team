#!/usr/bin/env bash
# Grunk loop - polls beads for needs-grunk work, invokes opencode to build.
# Delegates all common loop logic to skills/grug/scripts/run-agent-loop.sh.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || (cd "$SCRIPT_DIR/../../.." && pwd))"

GRUNK_MODEL="${GRUNK_MODEL:-}"
if [ -z "$GRUNK_MODEL" ]; then
  echo "Error: GRUNK_MODEL env var is not set."
  echo "Usage: GRUNK_MODEL=<model-name> bash .trogteam/run-grunk-loop.sh"
  exit 1
fi

export AGENT_NAME="Grunk"
export AGENT_MODEL="$GRUNK_MODEL"
export AGENT_LABEL="needs-grunk"
export AGENT_LOOP_MODE="grunk"
export POLL_INTERVAL="${GRUNK_POLL_INTERVAL:-30}"
export AGENT_PROMPT="You are Grunk. Load the grunk skill. Check beads for work labelled needs-grunk and process it. When all available work is done, exit."

exec bash "$REPO_DIR/skills/grug/scripts/run-agent-loop.sh"
