#!/usr/bin/env bash
POLL_INTERVAL="${GRUNK_POLL_INTERVAL:-30}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || (cd "$SCRIPT_DIR/.." && pwd))"

GRUNK_MODEL="${GRUNK_MODEL:-}"
if [ -z "$GRUNK_MODEL" ]; then
  echo "Error: GRUNK_MODEL env var is not set."
  echo "Usage: GRUNK_MODEL=<model-name> bash .trogteam/run-grunk-loop.sh"
  exit 1
fi

LOCK_DIR="$REPO_DIR/.trogteam"
LOCK_KEY=$(echo "$REPO_DIR" | md5sum 2>/dev/null | cut -d' ' -f1 || echo "$REPO_DIR" | md5 2>/dev/null || echo "$REPO_DIR" | cksum | cut -d' ' -f1)
LOCKFILE="$LOCK_DIR/.grunk-loop.$LOCK_KEY.lock"

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
    echo "Grunk loop already running (PID $LOCK_PID)"
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

echo "Grunk loop starting. Model: $GRUNK_MODEL. Poll interval: ${POLL_INTERVAL}s"
echo "Press Ctrl+C to stop."

while true; do
  WORK=$(cd "$REPO_DIR" && BD_ACTOR="Grunk" bd list --label-any needs-grunk --json 2>/dev/null || echo "[]")
  GRUNK_WORK=$([ "$WORK" != "[]" ] && [ -n "$WORK" ] && echo "yes" || echo "")
  if [ -n "$GRUNK_WORK" ]; then
    echo "[$(date '+%H:%M:%S')] Grunk work found. Invoking opencode..."
    GRUNK_PORT=$((RANDOM + 10000))
    cd "$REPO_DIR" && AGENT_LOOP_MODE=grunk opencode serve --port "$GRUNK_PORT" &
    SERVER_PID=$!
    if ! wait_for_server "$GRUNK_PORT" 30; then
      echo "[$(date '+%H:%M:%S')] ERROR: Server failed to start within 30s" >&2
      kill "$SERVER_PID" 2>/dev/null || true
      sleep "$POLL_INTERVAL"
      continue
    fi
    if ! opencode run --attach "http://127.0.0.1:$GRUNK_PORT" --model "$GRUNK_MODEL" --share \
      "You are Grunk. Load the grunk skill. Check beads for work labelled needs-grunk and process it. When all available work is done, exit."; then
      echo "[$(date '+%H:%M:%S')] ERROR: opencode session exited with error" >&2
    fi
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
    SERVER_PID=""
    echo "[$(date '+%H:%M:%S')] opencode session complete."
  else
    echo "[$(date '+%H:%M:%S')] No Grunk work found. Sleeping ${POLL_INTERVAL}s..."
  fi
  sleep "$POLL_INTERVAL"
done
