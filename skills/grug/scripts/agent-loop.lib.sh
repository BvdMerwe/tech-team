#!/usr/bin/env bash
# Shared utilities for agent loop scripts.
# Source this file to get common functions for both Grug and Grunk loops.

set -euo pipefail

# Must be sourced after these vars are set in parent script:
# - SCRIPT_DIR, REPO_DIR, AGENT_NAME, AGENT_MODEL, POLL_INTERVAL

LOCK_DIR="${LOCK_DIR:-$REPO_DIR/.trogteam}"
LOCK_KEY=$(echo "$REPO_DIR" | md5sum 2>/dev/null | cut -d' ' -f1 || echo "$REPO_DIR" | md5 2>/dev/null || echo "$REPO_DIR" | cksum | cut -d' ' -f1)
AGENT_NAME_LOWER=$(echo "$AGENT_NAME" | tr '[:upper:]' '[:lower:]')
LOCKFILE="$LOCK_DIR/.${AGENT_NAME_LOWER}-loop.$LOCK_KEY.lock"
LOG_PREFIX="${LOG_PREFIX:-$LOCK_DIR/${AGENT_NAME_LOWER}-loop.log}"

# Logging
log() {
  echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_PREFIX" >/dev/null 2>/dev/null || true
  echo "[$(date '+%H:%M:%S')] $1" >&2
}

# Server management
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


# Lock management
acquire_lock() {
  if [ -f "$LOCKFILE" ]; then
    LOCK_PID=$(cat "$LOCKFILE" 2>/dev/null || echo "")
    if [ -n "$LOCK_PID" ] && kill -0 "$LOCK_PID" 2>/dev/null; then
      echo "$AGENT_NAME loop already running (PID $LOCK_PID)"
      return 1
    fi
    rm -f "$LOCKFILE"
  fi
  echo "$$" > "$LOCKFILE"
  return 0
}

release_lock() {
  rm -f "$LOCKFILE"
}

cleanup() {
  release_lock
  if [ -n "${SERVER_PID:-}" ]; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
}

# Run the agent via opencode
run_agent() {
  local task_id="${1:-}"
  local task_title="${2:-}"
  local agent_prompt="$3"

  PORT=$((RANDOM + 10000))

  # Start server in current shell (not subshell) so $! is reliable
  # Use WORK_DIR if set (e.g. grunk worktree), otherwise fall back to REPO_DIR
  local serve_dir="${WORK_DIR:-$REPO_DIR}"
  cd "$serve_dir" && opencode serve --port "$PORT" &>/dev/null &
  SERVER_PID=$!
  log "Starting opencode serve on port $PORT (pid $SERVER_PID)"

  if ! wait_for_server "$PORT" 30; then
    log "ERROR: Server failed to start within 30s"
    kill "$SERVER_PID" 2>/dev/null || true
    return 1
  fi

  export AGENT_LOOP_MODE
  if ! opencode run --attach "http://127.0.0.1:$PORT" --model "$AGENT_MODEL" --title "${AGENT_NAME}/${task_id} $(date '+%H:%M')" "$agent_prompt"; then
    log "opencode session exited with error"
  fi

  kill "$SERVER_PID" 2>/dev/null || true
  wait "$SERVER_PID" 2>/dev/null || true
  SERVER_PID=""
  log "opencode session complete."
  return 0
}

# Get next task from beads
get_next_task() {
  local label="${1:-$AGENT_LABEL}"
  local tasks=$(cd "$REPO_DIR" && BD_ACTOR="$AGENT_NAME" bd list --label-any "$label" --json 2>/dev/null || echo "[]")
  echo "$tasks" | python3 -c "
import json,sys
tasks = json.load(sys.stdin)
if tasks:
  t = tasks[0]
  print(f\"{t.get('id', '')}|{t.get('title', '')}\")
" 2>/dev/null || echo ""
}

# Claim a task
claim_task() {
  local task_id="$1"
  cd "$REPO_DIR" && BD_ACTOR="$AGENT_NAME" bd update "$task_id" --claim 2>/dev/null
}