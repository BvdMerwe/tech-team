#!/usr/bin/env bash
# Grunk loop - polls beads for needs-grunk work, manages worktrees, invokes opencode to build.
# Uses shared agent-loop.lib.sh for common loop logic.
# Each task gets its own worktree for isolation.

set -euo pipefail

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

WORKTREE_DIR="$REPO_DIR/.worktrees"
STATE_FILE="$WORKTREE_DIR/.tracked.json"

# Source shared library
source "$(dirname "$0")/../grug/scripts/agent-loop.lib.sh"

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

main() {
  init_worktrees
  acquire_lock || exit 1
  trap cleanup EXIT SIGTERM SIGINT

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

      # Work in worktree directory
      WORK_DIR="$WORKTREE_PATH"

      AGENT_PROMPT="You are Grunk. Load the grunk skill. You are working in a git worktree at $WORKTREE_PATH. Task: $TASK_ID - $TASK_TITLE. Check beads, implement, tag pr-ready when done, then exit. Do NOT cleanup the worktree when done - Grug will handle that after review."

      run_agent "$TASK_ID" "$TASK_TITLE" "$AGENT_PROMPT"

      # Small delay before next poll
      sleep 2
    else
      log "No Grunk work found. Sleeping ${POLL_INTERVAL}s..."
      sleep "$POLL_INTERVAL"
    fi
  done
}

main "$@"