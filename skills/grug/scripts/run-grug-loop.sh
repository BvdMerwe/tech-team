#!/usr/bin/env bash
# Grug loop - polls beads for pr-ready work, invokes opencode to review.
# Delegates all common loop logic to skills/grug/scripts/run-agent-loop.sh.

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
export AGENT_PROMPT="You are Grug. Load the grug skill. Check beads for work labelled pr-ready and review it for complexity and obvious mistakes. Approve or send back. When all work reviewed, exit."

exec bash "$REPO_DIR/skills/grug/scripts/run-agent-loop.sh"
