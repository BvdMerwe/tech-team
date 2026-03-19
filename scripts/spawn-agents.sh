#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Both models are required — fail early with a clear message
if [ -z "${TL_MODEL:-}" ] || [ -z "${ENG_MODEL:-}" ]; then
  echo "Error: TL_MODEL and ENG_MODEL must both be set before spawning agents."
  echo ""
  echo "Usage:"
  echo "  TL_MODEL=<model> ENG_MODEL=<model> bash scripts/spawn-agents.sh"
  echo ""
  echo "Example:"
  echo "  TL_MODEL=claude-sonnet-4-5 ENG_MODEL=claude-haiku-3-5 bash scripts/spawn-agents.sh"
  exit 1
fi

# Make loop scripts executable if not already
chmod +x "$SCRIPT_DIR/run-tl-loop.sh"
chmod +x "$SCRIPT_DIR/run-eng-loop.sh"

echo "Spawning TL loop (model: $TL_MODEL)..."
echo "Spawning Engineer loop (model: $ENG_MODEL)..."

if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS: use osascript to open new Terminal windows, passing model env vars through
  osascript -e "tell application \"Terminal\" to do script \"TL_MODEL='$TL_MODEL' bash '$SCRIPT_DIR/run-tl-loop.sh'\""
  osascript -e "tell application \"Terminal\" to do script \"ENG_MODEL='$ENG_MODEL' bash '$SCRIPT_DIR/run-eng-loop.sh'\""
else
  # Linux: try gnome-terminal, fall back to xterm
  # Note: gnome-terminal detaches automatically; xterm needs explicit & for background
  gnome-terminal -- bash -c "TL_MODEL='$TL_MODEL' bash '$SCRIPT_DIR/run-tl-loop.sh'" 2>/dev/null \
    || TL_MODEL="$TL_MODEL" xterm -e bash "$SCRIPT_DIR/run-tl-loop.sh" &
  gnome-terminal -- bash -c "ENG_MODEL='$ENG_MODEL' bash '$SCRIPT_DIR/run-eng-loop.sh'" 2>/dev/null \
    || ENG_MODEL="$ENG_MODEL" xterm -e bash "$SCRIPT_DIR/run-eng-loop.sh" &
fi

echo ""
echo "TL and Engineer loops spawned in new terminal windows."
echo "To stop: close the terminal windows or press Ctrl+C in each."
