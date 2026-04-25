#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || (cd "$SCRIPT_DIR/../.." && pwd))"

if [ -z "${GRUG_MODEL:-}" ] || [ -z "${GRUNK_MODEL:-}" ]; then
  echo "Error: GRUG_MODEL and GRUNK_MODEL must both be set before spawning agents."
  echo ""
  echo "Usage:"
  echo "  GRUG_MODEL=<model> GRUNK_MODEL=<model> bash .trogteam/spawn-agents.sh"
  echo ""
  echo "Example:"
  echo "  GRUG_MODEL=anthropic/claude-sonnet-4-5 GRUNK_MODEL=opencode/big-pickle bash .trogteam/spawn-agents.sh"
  exit 1
fi

TROG_TEAM_DIR="$SKILL_DIR/.trogteam"
mkdir -p "$TROG_TEAM_DIR"

# Ensure directories are in .gitignore before loop scripts use them
grep -q "^.worktrees/$" "$SKILL_DIR/.gitignore" 2>/dev/null || echo ".worktrees/" >> "$SKILL_DIR/.gitignore"
grep -q "^.trogteam/$" "$SKILL_DIR/.gitignore" 2>/dev/null || echo ".trogteam/" >> "$SKILL_DIR/.gitignore"

# Always copy latest versions to .trogteam/ — keeps scripts up to date
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
mkdir -p "$REPO_ROOT/.trogteam"

# Try repo-local skills/ first, fall back to ~/.agents/skills/
if [ -f "$REPO_ROOT/skills/grug/scripts/run-grug-loop.sh" ]; then
  GRUG_SRC="$REPO_ROOT/skills/grug/scripts"
else
  GRUG_SRC="$HOME/.agents/skills/grug/scripts"
fi
if [ -f "$REPO_ROOT/skills/grunk/scripts/run-grunk-loop.sh" ]; then
  GRUNK_SRC="$REPO_ROOT/skills/grunk/scripts"
else
  GRUNK_SRC="$HOME/.agents/skills/grunk/scripts"
fi

cp -f "$GRUG_SRC/"*.sh "$REPO_ROOT/.trogteam/"
cp -f "$GRUNK_SRC/"*.sh "$REPO_ROOT/.trogteam/"
chmod +x "$REPO_ROOT/.trogteam/"*.sh

echo "Scripts updated from skills/"

# Compute lock key same way loop scripts do
LOCK_KEY=$(echo "$SKILL_DIR" | md5sum 2>/dev/null | cut -d' ' -f1 || echo "$SKILL_DIR" | md5 2>/dev/null || echo "$SKILL_DIR" | cksum | cut -d' ' -f1)
GRUG_LOCKFILE="$TROG_TEAM_DIR/.grug-loop.$LOCK_KEY.lock"
GRUNK_LOCKFILE="$TROG_TEAM_DIR/.grunk-loop.$LOCK_KEY.lock"

# Check grug lockfile
SPAWN_GRUG=true
if [ -f "$GRUG_LOCKFILE" ]; then
  GRUG_LOCK_PID=$(cat "$GRUG_LOCKFILE" 2>/dev/null || echo "")
  if [ -n "$GRUG_LOCK_PID" ] && kill -0 "$GRUG_LOCK_PID" 2>/dev/null; then
    echo "Grug loop already running (PID $GRUG_LOCK_PID) — skipping"
    SPAWN_GRUG=false
  else
    echo "Stale Grug lockfile found — cleaning up"
    rm -f "$GRUG_LOCKFILE"
  fi
fi

# Check grunk lockfile
SPAWN_GRUNK=true
if [ -f "$GRUNK_LOCKFILE" ]; then
  GRUNK_LOCK_PID=$(cat "$GRUNK_LOCKFILE" 2>/dev/null || echo "")
  if [ -n "$GRUNK_LOCK_PID" ] && kill -0 "$GRUNK_LOCK_PID" 2>/dev/null; then
    echo "Grunk loop already running (PID $GRUNK_LOCK_PID) — skipping"
    SPAWN_GRUNK=false
  else
    echo "Stale Grunk lockfile found — cleaning up"
    rm -f "$GRUNK_LOCKFILE"
  fi
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
  if [ "$SPAWN_GRUG" = true ]; then
    echo "Spawning Grug loop (model: $GRUG_MODEL)..."
    osascript -e "tell application \"Terminal\" to do script \"GRUG_MODEL='$GRUG_MODEL' bash '$GRUG_TARGET'\""
  fi
  if [ "$SPAWN_GRUNK" = true ]; then
    echo "Spawning Grunk loop (model: $GRUNK_MODEL)..."
    osascript -e "tell application \"Terminal\" to do script \"GRUNK_MODEL='$GRUNK_MODEL' bash '$GRUNK_TARGET'\""
  fi
else
  if [ "$SPAWN_GRUG" = true ]; then
    echo "Spawning Grug loop (model: $GRUG_MODEL)..."
    gnome-terminal -- bash -c "GRUG_MODEL='$GRUG_MODEL' bash '$GRUG_TARGET'" 2>/dev/null \
      || GRUG_MODEL="$GRUG_MODEL" xterm -e bash "$GRUG_TARGET" &
  fi
  if [ "$SPAWN_GRUNK" = true ]; then
    echo "Spawning Grunk loop (model: $GRUNK_MODEL)..."
    gnome-terminal -- bash -c "GRUNK_MODEL='$GRUNK_MODEL' bash '$GRUNK_TARGET'" 2>/dev/null \
      || GRUNK_MODEL="$GRUNK_MODEL" xterm -e bash "$GRUNK_TARGET" &
  fi
fi

if [ "$SPAWN_GRUG" = true ] || [ "$SPAWN_GRUNK" = true ]; then
  echo ""
  echo "Agent loops spawned in new terminal windows."
  echo "To stop: close the terminal windows or press Ctrl+C in each."
fi
