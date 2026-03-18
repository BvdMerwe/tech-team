# Feature: 3-Agent Team Loop

**Status:** Approved  
**Date:** 2026-03-18

## Problem Statement

The PO, TL, and Engineer skills exist as standalone, human-invoked tools. There is no mechanism for them to operate as a coordinated team. Each handoff requires the human to manually invoke the next agent. This adds friction and breaks the flow of automated feature delivery.

## User Stories

- As a developer, I want to invoke the PO skill, describe a feature, and have TL and Engineer pick up the work automatically — so I don't have to manually trigger each stage.
- As a developer, I want each skill to still work in individual mode (no loops, no spawning) — so I don't have to use team mode if I don't want to.
- As a developer, I want TL and Engineer to poll for work continuously in the background — so features get processed as soon as they are ready.

## Acceptance Criteria

- [ ] PO skill, after beads handoff, asks user if they want to spawn TL and Engineer loops
- [ ] If yes, PO runs `scripts/spawn-agents.sh` which opens two new terminal windows running TL and Engineer loops
- [ ] TL loop script: polls `bd ready` every 30s, invokes `opencode` with TL skill + task context when work is available, exits OpenCode cleanly after work is done, loops
- [ ] Engineer loop script: same pattern for engineer-assigned tasks
- [ ] `AGENT_LOOP_MODE=tl` / `AGENT_LOOP_MODE=engineer` env var is set by loop scripts when invoking OpenCode
- [ ] TL and Engineer skills detect `AGENT_LOOP_MODE` at session start (via `echo $AGENT_LOOP_MODE`) and adjust behavior: exit cleanly after work instead of waiting for user input
- [ ] `TL_MODEL` and `ENG_MODEL` env vars control which model each loop uses — both are required; scripts fail with a clear error message if either is not set
- [ ] Model is passed to `opencode run` via `--model $TL_MODEL` / `--model $ENG_MODEL`
- [ ] `spawn-agents.sh` validates that `TL_MODEL` and `ENG_MODEL` are set before opening terminals, and prints a helpful error if not
- [ ] All three skills continue to work without any scripts — individual mode is unchanged
- [ ] Beads label convention: PO tags new features `needs-tl-review`; TL tags tasks `needs-engineer`; Engineer tags completed work `pr-ready`; TL closes tasks after review
- [ ] Scripts live in `scripts/` directory in the tech-team repo
- [ ] `scripts/spawn-agents.sh` detects macOS vs Linux and opens terminals appropriately

## Out of Scope

- Windows support
- Auto-restart on crash (scripts can be restarted manually)
- Progress monitoring / status dashboard
- Slack/email notifications
- PO looping (PO is always human-invoked)

## Technical Design

### Architecture

```
USER'S TERMINAL
  opencode (PO skill loaded)
  ├── User types: "Add feature X"
  ├── PO brainstorms with user
  ├── PO writes spec + beads task (label: needs-tl-review)
  ├── PO asks: "Spin up TL and Engineer loops?"
  ├── If yes: runs scripts/spawn-agents.sh
  │     ├── opens new terminal: scripts/run-tl-loop.sh
  │     └── opens new terminal: scripts/run-eng-loop.sh
  └── PO stays open, waits for next feature request

[TL TERMINAL] scripts/run-tl-loop.sh
  └── loop:
        bd ready (filter: needs-tl-review OR pr-ready)
        → AGENT_LOOP_MODE=tl opencode "process TL work"
        → sleep 30
        → repeat

[ENGINEER TERMINAL] scripts/run-eng-loop.sh
  └── loop:
        bd ready (filter: needs-engineer)
        → AGENT_LOOP_MODE=engineer opencode "process engineer work"
        → sleep 30
        → repeat
```

**Beads is the shared state.** All agents read from and write to beads. No other shared state.

### Scripts

**`scripts/run-tl-loop.sh`**
```bash
#!/usr/bin/env bash
set -euo pipefail
POLL_INTERVAL="${TL_POLL_INTERVAL:-30}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# TL_MODEL is required
if [ -z "${TL_MODEL:-}" ]; then
  echo "Error: TL_MODEL env var is not set."
  echo "Usage: TL_MODEL=claude-sonnet-4-5 bash run-tl-loop.sh"
  exit 1
fi

while true; do
  # Check for TL-relevant work: features needing review or PRs ready for approval
  WORK=$(cd "$REPO_DIR" && BD_ACTOR="TL" bd list --status open --json 2>/dev/null || echo "")
  TL_WORK=$(echo "$WORK" | grep -E '"needs-tl-review"|"pr-ready"' || true)
  if [ -n "$TL_WORK" ]; then
    cd "$REPO_DIR" && AGENT_LOOP_MODE=tl opencode run --model "$TL_MODEL" \
      "You are the Tech Lead. Load the tech-lead skill from .opencode/skills/tech-lead/SKILL.md. Check beads for work labelled needs-tl-review or pr-ready and process it. When all available work is done, exit."
  fi
  sleep "$POLL_INTERVAL"
done
```

**`scripts/run-eng-loop.sh`**
```bash
#!/usr/bin/env bash
set -euo pipefail
POLL_INTERVAL="${ENG_POLL_INTERVAL:-30}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# ENG_MODEL is required
if [ -z "${ENG_MODEL:-}" ]; then
  echo "Error: ENG_MODEL env var is not set."
  echo "Usage: ENG_MODEL=claude-haiku-3-5 bash run-eng-loop.sh"
  exit 1
fi

while true; do
  # Check for engineer-assigned work
  WORK=$(cd "$REPO_DIR" && BD_ACTOR="Engineer" bd list --status open --json 2>/dev/null || echo "")
  ENG_WORK=$(echo "$WORK" | grep '"needs-engineer"' || true)
  if [ -n "$ENG_WORK" ]; then
    cd "$REPO_DIR" && AGENT_LOOP_MODE=engineer opencode run --model "$ENG_MODEL" \
      "You are the Engineer. Load the engineer skill from .opencode/skills/engineer/SKILL.md. Check beads for work labelled needs-engineer and process it. When all available work is done, exit."
  fi
  sleep "$POLL_INTERVAL"
done
```

**`scripts/spawn-agents.sh`**
```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Both models are required — fail early with a clear message
if [ -z "${TL_MODEL:-}" ] || [ -z "${ENG_MODEL:-}" ]; then
  echo "Error: TL_MODEL and ENG_MODEL must both be set."
  echo ""
  echo "Usage:"
  echo "  TL_MODEL=claude-sonnet-4-5 ENG_MODEL=claude-haiku-3-5 bash scripts/spawn-agents.sh"
  exit 1
fi

# Make loop scripts executable if not already
chmod +x "$SCRIPT_DIR/run-tl-loop.sh"
chmod +x "$SCRIPT_DIR/run-eng-loop.sh"

if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS: use osascript to open new Terminal windows, passing model env vars through
  osascript -e "tell application \"Terminal\" to do script \"TL_MODEL='$TL_MODEL' bash '$SCRIPT_DIR/run-tl-loop.sh'\""
  osascript -e "tell application \"Terminal\" to do script \"ENG_MODEL='$ENG_MODEL' bash '$SCRIPT_DIR/run-eng-loop.sh'\""
else
  # Linux: try gnome-terminal, fall back to xterm
  gnome-terminal -- bash -c "TL_MODEL='$TL_MODEL' bash '$SCRIPT_DIR/run-tl-loop.sh'" 2>/dev/null \
    || TL_MODEL="$TL_MODEL" xterm -e bash "$SCRIPT_DIR/run-tl-loop.sh" &
  gnome-terminal -- bash -c "ENG_MODEL='$ENG_MODEL' bash '$SCRIPT_DIR/run-eng-loop.sh'" 2>/dev/null \
    || ENG_MODEL="$ENG_MODEL" xterm -e bash "$SCRIPT_DIR/run-eng-loop.sh" &
fi

echo "TL loop spawned with model: $TL_MODEL"
echo "Engineer loop spawned with model: $ENG_MODEL"
echo "To stop: close the terminal windows or Ctrl+C in each."
```

### Skill Changes

**PO skill** — add section "Team Mode (Optional)":

After creating the beads handoff comment, ask the user:

> "Want me to spin up the TL and Engineer agent loops in background terminals? You'll need `TL_MODEL` and `ENG_MODEL` set in your environment (e.g. `TL_MODEL=claude-sonnet-4-5 ENG_MODEL=claude-haiku-3-5`). Are those set?"

- If **yes**: run `bash scripts/spawn-agents.sh` (it inherits the env vars from the current shell)
- If **no**: inform the user they can set those vars and run `scripts/spawn-agents.sh`, or run each loop script manually with the model var set

Either way, remain in session and await the next feature request.

Also: when creating the feature beads task, add the label `needs-tl-review`.

**TL skill** — add section "Loop Mode Detection":

At session start, run:
```bash
echo $AGENT_LOOP_MODE
```

If the output is `tl`, you are in loop mode. In loop mode:
- After processing all available work, exit cleanly
- Do not prompt for further input

Also: when creating engineer tasks, add the label `needs-engineer`. When reviewing `pr-ready` work, remove the label and close or return the task.

**Engineer skill** — add section "Loop Mode Detection":

At session start, run:
```bash
echo $AGENT_LOOP_MODE
```

If the output is `engineer`, you are in loop mode. In loop mode:
- After processing all available work, exit cleanly
- Do not prompt for further input

Also: when completing a task and creating a PR, add the label `pr-ready` to the beads task.

### Beads Label Convention

| Stage | Label | Set by | Detected by |
|-------|-------|--------|-------------|
| PO creates feature | `needs-tl-review` | PO | TL loop |
| TL creates engineer task | `needs-engineer` | TL | Engineer loop |
| Engineer submits PR | `pr-ready` | Engineer | TL loop |
| TL approves and closes | (closed) | TL | — |

## Success Metrics

- User can say "add feature X" to PO, answer yes to team mode prompt, and see TL and Engineer loop terminals open
- TL picks up the feature within one poll cycle (≤30s) and creates tasks
- Engineer picks up tasks within one poll cycle and begins implementation
- All three agents work in individual mode without any scripts or env vars

## Files to Create/Modify

| File | Action |
|------|--------|
| `scripts/run-tl-loop.sh` | Create (chmod +x) |
| `scripts/run-eng-loop.sh` | Create (chmod +x) |
| `scripts/spawn-agents.sh` | Create (chmod +x) |
| `.opencode/skills/product-owner/SKILL.md` | Add Team Mode section + needs-tl-review label |
| `.opencode/skills/tech-lead/SKILL.md` | Add Loop Mode Detection section + label conventions |
| `.opencode/skills/engineer/SKILL.md` | Add Loop Mode Detection section + pr-ready label |

## Implementation Notes

- Loop scripts use `opencode run "..."` (non-interactive mode) — not `opencode --print`
- `AGENT_LOOP_MODE` is set as an env var prefix on the `opencode run` invocation; the skill reads it via `echo $AGENT_LOOP_MODE` as its first bash command
- `TL_MODEL` and `ENG_MODEL` are required env vars; scripts exit with a clear error if not set
- Model is passed to `opencode run` via `--model $TL_MODEL` / `--model $ENG_MODEL`
- `spawn-agents.sh` passes model env vars through to new terminal windows via the `osascript` command string (macOS) or `bash -c "VAR=val bash script.sh"` pattern (Linux)
- `spawn-agents.sh` uses `osascript` on macOS (reliable) rather than `open -a Terminal script.sh` (unreliable)
- Scripts self-`chmod +x` their siblings via `spawn-agents.sh` to avoid permission issues after fresh clone
