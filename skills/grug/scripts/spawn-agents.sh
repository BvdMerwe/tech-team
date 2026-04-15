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
echo "Spawning Grug loop (model: $GRUG_MODEL)..."
echo "Spawning Grunk loop (model: $GRUNK_MODEL)..."

if [[ "$OSTYPE" == "darwin"* ]]; then
  osascript -e "tell application \"Terminal\" to do script \"GRUG_MODEL='$GRUG_MODEL' bash '$GRUG_TARGET'\""
  osascript -e "tell application \"Terminal\" to do script \"GRUNK_MODEL='$GRUNK_MODEL' bash '$GRUNK_TARGET'\""
else
  gnome-terminal -- bash -c "GRUG_MODEL='$GRUG_MODEL' bash '$GRUG_TARGET'" 2>/dev/null \
    || GRUG_MODEL="$GRUG_MODEL" xterm -e bash "$GRUG_TARGET" &
  gnome-terminal -- bash -c "GRUNK_MODEL='$GRUNK_MODEL' bash '$GRUNK_TARGET'" 2>/dev/null \
    || GRUNK_MODEL="$GRUNK_MODEL" xterm -e bash "$GRUNK_TARGET" &
fi

echo ""
echo "Grug and Grunk loops spawned in new terminal windows."
echo "To stop: close the terminal windows or press Ctrl+C in each."
