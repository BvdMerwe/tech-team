#!/usr/bin/env bash
# Grunk loop - polls beads for needs-grunk work, manages worktrees, invokes opencode to build.
# Each task gets its own worktree for isolation.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || (cd "$SCRIPT_DIR/../../.." && pwd))"
WORKTREE_DIR="$REPO_DIR/.worktrees"
STATE_FILE="$WORKTREE_DIR/.tracked.json"
LOG_PREFIX="$REPO_DIR/.trogteam/grunk-loop.log"

GRUNK_MODEL="${GRUNK_MODEL:-}"
if [ -z "$GRUNK_MODEL" ]; then
  echo "Error: GRUNK_MODEL env var is not set."
  echo "Usage: GRUNK_MODEL=<model-name> bash .trogteam/run-grunk-loop.sh"
  exit 1
fi

export AGENT_NAME="Grunk"
export AGENT_MODEL="$GRUNK_MODEL"
export POLL_INTERVAL="${GRUNK_POLL_INTERVAL:-30}"

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

log() {
  echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_PREFIX" 2>/dev/null || echo "[$(date '+%H:%M:%S')] $1"
}

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

# Initialize worktree directory
init_worktrees() {
  mkdir -p "$WORKTREE_DIR"
  if [ ! -f "$STATE_FILE" ]; then
    echo '{}' > "$STATE_FILE"
  fi
  git check-ignore -q "$WORKTREE_DIR" || {
    echo "WARNING: .worktrees is not gitignored. This is a bug."
  }
}

# Read state
get_state() {
  cat "$STATE_FILE" 2>/dev/null || echo '{}'
}

# Write state
save_state() {
  cat > "$STATE_FILE"
}

# Get worktree for a task
get_worktree_for_task() {
  local task_id="$1"
  local state=$(get_state)
  echo "$state" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('$task_id', {}).get('path', ''))" 2>/dev/null || echo ""
}

# Check if worktree exists and is valid
worktree_exists() {
  local path="$1"
  [ -d "$path" ] && [ -d "$path/.git" ] && git -C "$path" rev-parse --git-dir >/dev/null 2>&1
}

# Create a new worktree for a task
create_worktree() {
  local task_id="$1"
  local task_title="$2"
  local safe_name=$(echo "$task_title" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-' | head -c 50)
  local branch_name="grunk/${task_id}-${safe_name}"
  local worktree_path="$WORKTREE_DIR/${task_id}-${safe_name}"

  log "Creating worktree for $task_id at $worktree_path"

  # Ensure main is up to date
  cd "$REPO_DIR"
  git checkout main 2>/dev/null || git checkout master 2>/dev/null
  git pull origin main 2>/dev/null || true

  # Create worktree with new branch
  git worktree add "$worktree_path" -b "$branch_name"

  # Track in state
  local state=$(get_state)
  local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  echo "$state" | python3 -c "
import json,sys
d=json.load(sys.stdin)
d['$task_id'] = {
  'task_id': '$task_id',
  'branch': '$branch_name',
  'path': '$worktree_path',
  'status': 'in-progress',
  'created_at': '$timestamp',
  'updated_at': '$timestamp'
}
print(json.dumps(d, indent=2))
" > "$STATE_FILE"

  # Run project setup if needed
  if [ -f "$worktree_path/package.json" ]; then
    log "Running npm install in $worktree_path"
    npm install --prefix "$worktree_path" 2>&1 | tail -5
  fi

  # Verify baseline (optional, non-fatal)
  # if [ -f "$worktree_path/package.json" ]; then
  #   if ! npm test --prefix "$worktree_path" --silent 2>/dev/null; then
  #     log "WARNING: Baseline tests failed in new worktree"
  #   fi
  # fi

  echo "$worktree_path"
}

# Update task status in state
update_task_status() {
  local task_id="$1"
  local status="$2"
  local state=$(get_state)
  local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  echo "$state" | python3 -c "
import json,sys
d=json.load(sys.stdin)
if '$task_id' in d:
  d['$task_id']['status'] = '$status'
  d['$task_id']['updated_at'] = '$timestamp'
print(json.dumps(d, indent=2))
" > "$STATE_FILE"
}

# Get next task from beads
get_next_task() {
  local tasks=$(cd "$REPO_DIR" && BD_ACTOR="Grunk" bd list --label-any needs-grunk --json 2>/dev/null || echo "[]")
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
  cd "$REPO_DIR" && BD_ACTOR="Grunk" bd update "$task_id" --claim 2>/dev/null
}

# Main loop
main() {
  init_worktrees
  log "Grunk loop starting. Model: $AGENT_MODEL. Poll interval: ${POLL_INTERVAL}s"
  log "Worktree directory: $WORKTREE_DIR"
  log "Press Ctrl+C to stop."

  while true; do
    TASK_INFO=$(get_next_task)
    if [ -n "$TASK_INFO" ]; then
      TASK_ID=$(echo "$TASK_INFO" | cut -d'|' -f1)
      TASK_TITLE=$(echo "$TASK_INFO" | cut -d'|' -f2-)

      log "Found work: $TASK_ID - $TASK_TITLE"

      # Check if worktree already exists
      WORKTREE_PATH=$(get_worktree_for_task "$TASK_ID")

      if [ -n "$WORKTREE_PATH" ] && worktree_exists "$WORKTREE_PATH"; then
        log "Resuming existing worktree: $WORKTREE_PATH"
      else
        WORKTREE_PATH=$(create_worktree "$TASK_ID" "$TASK_TITLE")
        claim_task "$TASK_ID"
        log "Created new worktree: $WORKTREE_PATH"
      fi

      # Update status
      update_task_status "$TASK_ID" "in-progress"

      # Start opencode server
      PORT=$((RANDOM + 10000))
      log "Starting opencode serve on port $PORT"

      cd "$WORKTREE_PATH" && opencode serve --port "$PORT" &
      SERVER_PID=$!

      if ! wait_for_server "$PORT" 30; then
        log "ERROR: Server failed to start within 30s"
        kill "$SERVER_PID" 2>/dev/null || true
        sleep "$POLL_INTERVAL"
        continue
      fi

      AGENT_PROMPT="You are Grunk. Load the grunk skill. You are working in a git worktree at $WORKTREE_PATH. Task: $TASK_ID - $TASK_TITLE. Check beads, implement, tag pr-ready when done, then exit. Do NOT cleanup the worktree when done - Grug will handle that after review."

      export WORKTREE_PATH AGENT_LOOP_MODE=grunk
      if ! opencode run --attach "http://127.0.0.1:$PORT" --model "$AGENT_MODEL" --share "$AGENT_PROMPT"; then
        log "opencode session exited with error"
      fi

      kill "$SERVER_PID" 2>/dev/null || true
      wait "$SERVER_PID" 2>/dev/null || true
      SERVER_PID=""
      log "opencode session complete."

      # Small delay before next poll
      sleep 2
    else
      log "No Grunk work found. Sleeping ${POLL_INTERVAL}s..."
      sleep "$POLL_INTERVAL"
    fi
  done
}

main "$@"