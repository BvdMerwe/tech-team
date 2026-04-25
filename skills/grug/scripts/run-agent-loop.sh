#!/usr/bin/env bash
# Shared agent loop runner. Called by run-grug-loop.sh and run-grunk-loop.sh.
# Required env vars:
#   AGENT_NAME       - human name (e.g. "Grug")
#   AGENT_MODEL      - model string passed to opencode
#   AGENT_LABEL      - beads label to poll (e.g. "pr-ready")
#   AGENT_LOOP_MODE  - loop mode passed to opencode serve (e.g. "grug")
#   AGENT_PROMPT     - prompt passed to opencode run
#   POLL_INTERVAL    - seconds between polls (default: 30)

set -euo pipefail

POLL_INTERVAL="${POLL_INTERVAL:-30}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || (cd "$SCRIPT_DIR/.." && pwd))"

LOCK_DIR="$REPO_DIR/.trogteam"
LOCK_KEY=$(echo "$REPO_DIR" | md5sum 2>/dev/null | cut -d' ' -f1 || echo "$REPO_DIR" | md5 2>/dev/null || echo "$REPO_DIR" | cksum | cut -d' ' -f1)
AGENT_NAME_LOWER=$(echo "$AGENT_NAME" | tr '[:upper:]' '[:lower:]')
LOCKFILE="$LOCK_DIR/.${AGENT_NAME_LOWER}-loop.$LOCK_KEY.lock"

cleanup() {
  rm -f "$LOCKFILE"
  if [ -n "${SERVER_PID:-}" ]; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT SIGTERM SIGINT

if [ -f "$LOCKFILE" ]; then
  LOCK_PID=$(cat "$LOCKFILE" 2>/dev/null || echo "")
  if [ -n "$LOCK_PID" ] && kill -0 "$LOCK_PID" 2>/dev/null; then
    echo "$AGENT_NAME loop already running (PID $LOCK_PID)"
    exit 1
  fi
  rm -f "$LOCKFILE"
fi

echo "$$" > "$LOCKFILE"

wait_for_server() {
  local port=$1
  local timeout=${2:-30}
  local elapsed=0
  while [ $elapsed -lt $timeout ]; do
    if nc -z 127.0.0.1 "$port" 2>/dev/null; then
      return 0
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done
  return 1
}

echo "$AGENT_NAME loop starting. Model: $AGENT_MODEL. Poll interval: ${POLL_INTERVAL}s"
echo "Press Ctrl+C to stop."

while true; do
  WORK=$(cd "$REPO_DIR" && BD_ACTOR="$AGENT_NAME" bd list --label-any "$AGENT_LABEL" --json 2>/dev/null || echo "[]")
  HAS_WORK=$([ "$WORK" != "[]" ] && [ -n "$WORK" ] && echo "yes" || echo "")
  if [ -n "$HAS_WORK" ]; then
    echo "[$(date '+%H:%M:%S')] $AGENT_NAME work found. Invoking opencode..."
    PORT=$((RANDOM + 10000))
    cd "$REPO_DIR" && AGENT_LOOP_MODE="$AGENT_LOOP_MODE" opencode serve --port "$PORT" &
    SERVER_PID=$!
    if ! wait_for_server "$PORT" 30; then
      echo "[$(date '+%H:%M:%S')] ERROR: Server failed to start within 30s" >&2
      kill "$SERVER_PID" 2>/dev/null || true
      sleep "$POLL_INTERVAL"
      continue
    fi
    if ! opencode run --attach "http://127.0.0.1:$PORT" --model "$AGENT_MODEL" "$AGENT_PROMPT"; then
      echo "[$(date '+%H:%M:%S')] ERROR: opencode session exited with error" >&2
    fi
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
    SERVER_PID=""
    echo "[$(date '+%H:%M:%S')] opencode session complete."
  else
    echo "[$(date '+%H:%M:%S')] No $AGENT_NAME work found. Sleeping ${POLL_INTERVAL}s..."
  fi
  sleep "$POLL_INTERVAL"
done
