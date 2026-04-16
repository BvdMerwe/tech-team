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

TECH_TEAM_DIR="$SKILL_DIR/.trogteam"
mkdir -p "$TECH_TEAM_DIR"

GRUG_SOURCE="$SKILL_DIR/skills/grug/scripts/run-grug-loop.sh"
GRUNK_SOURCE="$SKILL_DIR/skills/grunk/scripts/run-grunk-loop.sh"
GRUG_TARGET="$TECH_TEAM_DIR/run-grug-loop.sh"
GRUNK_TARGET="$TECH_TEAM_DIR/run-grunk-loop.sh"

if [ ! -f "$GRUG_SOURCE" ]; then
  echo "Error: Grug script not found at $GRUG_SOURCE"
  exit 1
fi
if [ ! -f "$GRUNK_SOURCE" ]; then
  echo "Error: Grunk script not found at $GRUNK_SOURCE"
  exit 1
fi

cp -f "$GRUG_SOURCE" "$GRUG_TARGET"
cp -f "$GRUNK_SOURCE" "$GRUNK_TARGET"
chmod +x "$GRUG_TARGET" "$GRUNK_TARGET"

echo "Scripts synced from skills/ to .trogteam/"

# Compute lock key same way loop scripts do
LOCK_KEY=$(echo "$SKILL_DIR" | md5sum 2>/dev/null | cut -d' ' -f1 || echo "$SKILL_DIR" | md5 2>/dev/null || echo "$SKILL_DIR" | cksum | cut -d' ' -f1)
GRUG_LOCKFILE="$TECH_TEAM_DIR/.grug-loop.$LOCK_KEY.lock"
GRUNK_LOCKFILE="$TECH_TEAM_DIR/.grunk-loop.$LOCK_KEY.lock"

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
