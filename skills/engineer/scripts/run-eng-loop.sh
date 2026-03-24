#!/usr/bin/env bash
set -euo pipefail
POLL_INTERVAL="${ENG_POLL_INTERVAL:-30}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# ENG_MODEL is required
if [ -z "${ENG_MODEL:-}" ]; then
  echo "Error: ENG_MODEL env var is not set."
  echo "Usage: ENG_MODEL=<model-name> bash .tech-team/run-eng-loop.sh"
  echo "Example: ENG_MODEL=claude-haiku-3-5 bash .tech-team/run-eng-loop.sh"
  exit 1
fi

echo "Engineer loop starting. Model: $ENG_MODEL. Poll interval: ${POLL_INTERVAL}s"
echo "Press Ctrl+C to stop."

while true; do
  # Check for engineer-assigned work
  # Use --label-any (not --status open) so in_progress tasks are also found
  WORK=$(cd "$REPO_DIR" && BD_ACTOR="Engineer" bd list --label-any needs-engineer --json 2>/dev/null || echo "[]")
  ENG_WORK=$([ "$WORK" != "[]" ] && [ -n "$WORK" ] && echo "yes" || echo "")
  if [ -n "$ENG_WORK" ]; then
    echo "[$(date '+%H:%M:%S')] Engineer work found. Invoking opencode..."
    # Start a temporary server, run the session, then shut it down
    ENG_PORT=$((RANDOM + 10000))
    cd "$REPO_DIR" && AGENT_LOOP_MODE=engineer opencode serve --port "$ENG_PORT" &
    SERVER_PID=$!
    sleep 3  # Give server time to start
    opencode run --attach "http://127.0.0.1:$ENG_PORT" --model "$ENG_MODEL" \
      "You are the Engineer. Load the engineer skill. Check beads for work labelled needs-engineer and process it. When all available work is done, exit."
    kill "$SERVER_PID" 2>/dev/null || true
    echo "[$(date '+%H:%M:%S')] opencode session complete."
  else
    echo "[$(date '+%H:%M:%S')] No engineer work found. Sleeping ${POLL_INTERVAL}s..."
  fi
  sleep "$POLL_INTERVAL"
done
