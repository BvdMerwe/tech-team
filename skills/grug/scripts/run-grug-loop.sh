#!/usr/bin/env bash
POLL_INTERVAL="${GRUG_POLL_INTERVAL:-30}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || (cd "$SCRIPT_DIR/.." && pwd))"

GRUG_MODEL="${GRUG_MODEL:-}"
if [ -z "$GRUG_MODEL" ]; then
  echo "Error: GRUG_MODEL env var is not set."
  echo "Usage: GRUG_MODEL=<model-name> bash .tech-team/run-grug-loop.sh"
  exit 1
fi

LOCK_DIR="$REPO_DIR/.tech-team"
LOCK_KEY=$(echo "$REPO_DIR" | md5sum 2>/dev/null | cut -d' ' -f1 || echo "$REPO_DIR" | md5 2>/dev/null || echo "$REPO_DIR" | cksum | cut -d' ' -f1)
LOCKFILE="$LOCK_DIR/.grug-loop.$LOCK_KEY.lock"

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
    echo "Grug loop already running (PID $LOCK_PID)"
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

echo "Grug loop starting. Model: $GRUG_MODEL. Poll interval: ${POLL_INTERVAL}s"
echo "Press Ctrl+C to stop."

while true; do
  WORK=$(cd "$REPO_DIR" && BD_ACTOR="Grug" bd list --label-any pr-ready --json 2>/dev/null || echo "[]")
  GRUG_WORK=$([ "$WORK" != "[]" ] && [ -n "$WORK" ] && echo "yes" || echo "")
  if [ -n "$GRUG_WORK" ]; then
    echo "[$(date '+%H:%M:%S')] Grug review work found. Invoking opencode..."
    GRUG_PORT=$((RANDOM + 10000))
    cd "$REPO_DIR" && AGENT_LOOP_MODE=grug opencode serve --port "$GRUG_PORT" &
    SERVER_PID=$!
    if ! wait_for_server "$GRUG_PORT" 30; then
      echo "[$(date '+%H:%M:%S')] ERROR: Server failed to start within 30s" >&2
      kill "$SERVER_PID" 2>/dev/null || true
      sleep "$POLL_INTERVAL"
      continue
    fi
    if ! opencode run --attach "http://127.0.0.1:$GRUG_PORT" --model "$GRUG_MODEL" --share \
      "You are Grug. Load the grug skill. Check beads for work labelled pr-ready and review it for complexity and obvious mistakes. Approve or send back. When all work reviewed, exit."; then
      echo "[$(date '+%H:%M:%S')] ERROR: opencode session exited with error" >&2
    fi
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
    SERVER_PID=""
    echo "[$(date '+%H:%M:%S')] opencode session complete."
  else
    echo "[$(date '+%H:%M:%S')] No Grug review work found. Sleeping ${POLL_INTERVAL}s..."
  fi
  sleep "$POLL_INTERVAL"
done
