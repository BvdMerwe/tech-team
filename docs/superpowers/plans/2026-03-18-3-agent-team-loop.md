# 3-Agent Team Loop Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add optional team-loop mode to the PO/TL/Engineer skill trio — shell scripts that poll beads and invoke each agent automatically, while leaving individual skill invocation completely unchanged.

**Architecture:** Three shell scripts (`run-tl-loop.sh`, `run-eng-loop.sh`, `spawn-agents.sh`) handle the looping harness. The skills themselves are updated with small, additive sections: loop-mode detection for TL and Engineer (via `AGENT_LOOP_MODE` env var), team-mode offer for PO (spawn prompt + model var guidance), and beads label conventions for all three.

**Tech Stack:** Bash, opencode CLI, beads (bd CLI), osascript (macOS), git

---

## Chunk 1: Shell Scripts

### Task 1: Create `scripts/run-tl-loop.sh`

**Files:**
- Create: `scripts/run-tl-loop.sh`

- [ ] **Step 1: Write the file**

```bash
#!/usr/bin/env bash
set -euo pipefail
POLL_INTERVAL="${TL_POLL_INTERVAL:-30}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# TL_MODEL is required
if [ -z "${TL_MODEL:-}" ]; then
  echo "Error: TL_MODEL env var is not set."
  echo "Usage: TL_MODEL=<model-name> bash run-tl-loop.sh"
  echo "Example: TL_MODEL=claude-sonnet-4-5 bash scripts/run-tl-loop.sh"
  exit 1
fi

echo "TL loop starting. Model: $TL_MODEL. Poll interval: ${POLL_INTERVAL}s"
echo "Press Ctrl+C to stop."

while true; do
  # Check for TL-relevant work: features needing review or PRs ready for approval
  WORK=$(cd "$REPO_DIR" && BD_ACTOR="TL" bd list --status open --json 2>/dev/null || echo "")
  TL_WORK=$(echo "$WORK" | grep -E '"needs-tl-review"|"pr-ready"' || true)
  if [ -n "$TL_WORK" ]; then
    echo "[$(date '+%H:%M:%S')] TL work found. Invoking opencode..."
    cd "$REPO_DIR" && AGENT_LOOP_MODE=tl opencode run --model "$TL_MODEL" \
      "You are the Tech Lead. Load the tech-lead skill from .opencode/skills/tech-lead/SKILL.md. Check beads for work labelled needs-tl-review or pr-ready and process it. When all available work is done, exit."
    echo "[$(date '+%H:%M:%S')] opencode session complete."
  else
    echo "[$(date '+%H:%M:%S')] No TL work found. Sleeping ${POLL_INTERVAL}s..."
  fi
  sleep "$POLL_INTERVAL"
done
```

- [ ] **Step 2: Make executable**

Run: `chmod +x scripts/run-tl-loop.sh`

- [ ] **Step 3: Verify the file exists and is executable**

Run: `ls -la scripts/run-tl-loop.sh`
Expected: `-rwxr-xr-x` permissions

- [ ] **Step 4: Commit**

```bash
git add scripts/run-tl-loop.sh
git commit -m "feat(scripts): add TL loop script with model validation"
```

---

### Task 2: Create `scripts/run-eng-loop.sh`

**Files:**
- Create: `scripts/run-eng-loop.sh`

- [ ] **Step 1: Write the file**

```bash
#!/usr/bin/env bash
set -euo pipefail
POLL_INTERVAL="${ENG_POLL_INTERVAL:-30}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# ENG_MODEL is required
if [ -z "${ENG_MODEL:-}" ]; then
  echo "Error: ENG_MODEL env var is not set."
  echo "Usage: ENG_MODEL=<model-name> bash run-eng-loop.sh"
  echo "Example: ENG_MODEL=claude-haiku-3-5 bash scripts/run-eng-loop.sh"
  exit 1
fi

echo "Engineer loop starting. Model: $ENG_MODEL. Poll interval: ${POLL_INTERVAL}s"
echo "Press Ctrl+C to stop."

while true; do
  # Check for engineer-assigned work
  WORK=$(cd "$REPO_DIR" && BD_ACTOR="Engineer" bd list --status open --json 2>/dev/null || echo "")
  ENG_WORK=$(echo "$WORK" | grep '"needs-engineer"' || true)
  if [ -n "$ENG_WORK" ]; then
    echo "[$(date '+%H:%M:%S')] Engineer work found. Invoking opencode..."
    cd "$REPO_DIR" && AGENT_LOOP_MODE=engineer opencode run --model "$ENG_MODEL" \
      "You are the Engineer. Load the engineer skill from .opencode/skills/engineer/SKILL.md. Check beads for work labelled needs-engineer and process it. When all available work is done, exit."
    echo "[$(date '+%H:%M:%S')] opencode session complete."
  else
    echo "[$(date '+%H:%M:%S')] No engineer work found. Sleeping ${POLL_INTERVAL}s..."
  fi
  sleep "$POLL_INTERVAL"
done
```

- [ ] **Step 2: Make executable**

Run: `chmod +x scripts/run-eng-loop.sh`

- [ ] **Step 3: Verify the file exists and is executable**

Run: `ls -la scripts/run-eng-loop.sh`
Expected: `-rwxr-xr-x` permissions

- [ ] **Step 4: Commit**

```bash
git add scripts/run-eng-loop.sh
git commit -m "feat(scripts): add Engineer loop script with model validation"
```

---

### Task 3: Create `scripts/spawn-agents.sh`

**Files:**
- Create: `scripts/spawn-agents.sh`

- [ ] **Step 1: Write the file**

```bash
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
```

- [ ] **Step 2: Make executable**

Run: `chmod +x scripts/spawn-agents.sh`

- [ ] **Step 3: Verify all three scripts exist and are executable**

Run: `ls -la scripts/`
Expected: `run-tl-loop.sh`, `run-eng-loop.sh`, `spawn-agents.sh` all with `rwxr-xr-x`

- [ ] **Step 4: Commit**

```bash
git add scripts/spawn-agents.sh
git commit -m "feat(scripts): add spawn-agents.sh to open TL and Engineer loops in new terminals"
```

---

## Chunk 2: Skill Updates

### Task 4: Update PO skill — Team Mode section + beads label

**Files:**
- Modify: `.opencode/skills/product-owner/SKILL.md`

The PO skill needs two additions:
1. Tag feature beads tasks with `needs-tl-review` label when creating them
2. After handoff, offer to spawn agent loops (with model var guidance)

- [ ] **Step 1: Add `needs-tl-review` label to the beads create command**

In `.opencode/skills/product-owner/SKILL.md`, find this exact text:
```
BD_ACTOR="PO" bd create "[Feature Name] - [Brief Description]" -t feature -p [1-3]
```

Replace with (`--labels` plural, as required by the bd CLI):
```
BD_ACTOR="PO" bd create "[Feature Name] - [Brief Description]" -t feature -p [1-3] --labels needs-tl-review
```

- [ ] **Step 2: Also update the Workflow Example bd create command for consistency**

Find this exact text:
```
BD_ACTOR="PO" bd create "Add QR code analytics" -t feature -p 2
```

Replace with:
```
BD_ACTOR="PO" bd create "Add QR code analytics" -t feature -p 2 --labels needs-tl-review
```

- [ ] **Step 3: Add Team Mode section after "Handoff to Tech Lead"**

Find this exact text (the end of the "Handoff to Tech Lead" section):
```
**You may need to iterate if TL finds technical issues:**
- Work with user to adjust scope
- Revise acceptance criteria
- Get user approval on changes
```

Replace with:
```
**You may need to iterate if TL finds technical issues:**
- Work with user to adjust scope
- Revise acceptance criteria
- Get user approval on changes

### 5. Team Mode (Optional)

After completing the beads handoff, offer to spin up the agent loops:

> "Want me to start the TL and Engineer agent loops so this gets worked on automatically?
> This requires `TL_MODEL` and `ENG_MODEL` to be set in your environment.
> Example: `TL_MODEL=claude-sonnet-4-5 ENG_MODEL=claude-haiku-3-5`
> Are those set?"

- If **yes**: run `bash scripts/spawn-agents.sh` (it inherits the env vars from your shell)
- If **no**: let the user know they can run it manually:
  ```bash
  TL_MODEL=<model> ENG_MODEL=<model> bash scripts/spawn-agents.sh
  ```
  Or run each loop separately:
  ```bash
  TL_MODEL=<model> bash scripts/run-tl-loop.sh
  ENG_MODEL=<model> bash scripts/run-eng-loop.sh
  ```

Either way, **remain in session** and await the next feature request.
```

- [ ] **Step 4: Verify the changes**

Run:
```bash
grep -n "needs-tl-review" .opencode/skills/product-owner/SKILL.md
grep -n "Team Mode" .opencode/skills/product-owner/SKILL.md
```
Expected: Both return at least one matching line

- [ ] **Step 5: Commit**

```bash
git add .opencode/skills/product-owner/SKILL.md
git commit -m "feat(skills): add team mode offer and needs-tl-review label to PO skill"
```

---

### Task 5: Update TL skill — Loop Mode Detection + label conventions

**Files:**
- Modify: `.opencode/skills/tech-lead/SKILL.md`

The TL skill needs three additions:
1. Loop Mode Detection at session start (after the GUARDRAILS check)
2. `needs-engineer` label convention in Task Management
3. `pr-ready` label handling in Technical Review

- [ ] **Step 1: Add loop mode detection to Session Start Protocol**

In `.opencode/skills/tech-lead/SKILL.md`, find this exact text (the end of Session Start Protocol):
```
**If NOT found:** The engineer will create it when they start work. Proceed with general knowledge.
```

Replace with:
```
**If NOT found:** The engineer will create it when they start work. Proceed with general knowledge.

**Step 2: Check for loop mode**

```bash
echo $AGENT_LOOP_MODE
```

If the output is `tl`, you are running in **loop mode** (invoked by `scripts/run-tl-loop.sh`).

In loop mode:
- Process all available work as normal
- After all work is done, **exit cleanly** — do not prompt for further input
- The loop script will re-invoke you when new work arrives
```

- [ ] **Step 2: Add `needs-engineer` label convention to Task Management**

Find this exact text (the "Assign and track" block in Task Management):
```
**Assign and track:**
```bash
BD_ACTOR="TL" bd update [task-id] --claim [engineer-name]
BD_ACTOR="TL" bd update [task-id] --status in_progress
BD_ACTOR="TL" bd list --status in_progress
```
```

Replace with:
```
**Assign and track:**
```bash
BD_ACTOR="TL" bd update [task-id] --claim [engineer-name]
BD_ACTOR="TL" bd update [task-id] --status in_progress --add-label needs-engineer
BD_ACTOR="TL" bd list --status in_progress
```

> Always add the `needs-engineer` label when moving a task to `in_progress` — this is how the Engineer loop detects available work.
```

- [ ] **Step 3: Add `pr-ready` label handling to Technical Review**

Find this exact text (the review workflow list in Technical Review):
```
**Review workflow:**
1. Engineer marks task complete
2. TL examines code/test output
3. TL approves or requests changes via beads comment
4. If changes needed, task returns to engineer
```

Replace with:
```
**Review workflow:**
1. Engineer marks task complete and adds `pr-ready` label
2. TL loop detects `pr-ready` label and invokes TL to review
3. TL examines code/test output
4. If approved: close the task (`BD_ACTOR="TL" bd close [task-id] --reason "Approved"`)
5. If changes needed: remove the label and comment with feedback:
   ```bash
   BD_ACTOR="TL" bd update [task-id] --remove-label pr-ready
   BD_ACTOR="TL" bd comments add [task-id] "Changes requested: [feedback]"
   ```
   The engineer loop will pick up the task again when the label is removed.
```

- [ ] **Step 4: Verify the changes**

Run:
```bash
grep -n "loop mode\|AGENT_LOOP_MODE" .opencode/skills/tech-lead/SKILL.md
grep -n "needs-engineer" .opencode/skills/tech-lead/SKILL.md
grep -n "pr-ready\|remove-label" .opencode/skills/tech-lead/SKILL.md
```
Expected: Each grep returns at least one matching line

- [ ] **Step 5: Commit**

```bash
git add .opencode/skills/tech-lead/SKILL.md
git commit -m "feat(skills): add loop mode detection and label conventions to TL skill"
```

---

### Task 6: Update Engineer skill — Loop Mode Detection + pr-ready label

**Files:**
- Modify: `.opencode/skills/engineer/SKILL.md`

The Engineer skill needs two additions:
1. Loop Mode Detection at session start (after the existing 3 GUARDRAILS steps)
2. Tag completed tasks with `pr-ready` after creating a PR

- [ ] **Step 1: Add loop mode detection after the existing Session Start Protocol steps**

In `.opencode/skills/engineer/SKILL.md`, find this exact text (the end of the Session Start Protocol, Step 3):
```
Load this context into your session. Know the:
- Quality gates (MUST run these before every commit)
- Tech stack (so you use correct patterns)
- Key files (where things are located)
- Common patterns (how things are done here)
```

Replace with:
```
Load this context into your session. Know the:
- Quality gates (MUST run these before every commit)
- Tech stack (so you use correct patterns)
- Key files (where things are located)
- Common patterns (how things are done here)

**Step 4: Check for loop mode**

```bash
echo $AGENT_LOOP_MODE
```

If the output is `engineer`, you are running in **loop mode** (invoked by `scripts/run-eng-loop.sh`).

In loop mode:
- Process all available work as normal
- After all work is done, **exit cleanly** — do not prompt for further input
- The loop script will re-invoke you when new work arrives
```

- [ ] **Step 2: Add `pr-ready` label step to the Git Workflow section**

Find this exact text (end of the Git Workflow section):
```
5. **Push and create PR:**
   ```bash
   git push origin feature/[task-id]-[brief-description]
   ```
   
   Create PR for human/TL review
```

Replace with:
```
5. **Push and create PR:**
   ```bash
   git push origin feature/[task-id]-[brief-description]
   ```
   
   Create PR for human/TL review

6. **Tag task as pr-ready:**
   ```bash
   BD_ACTOR="Engineer" bd update [task-id] --add-label pr-ready
   BD_ACTOR="Engineer" bd comments add [task-id] "PR created: [PR URL]. Ready for TL review."
   ```
   This signals the TL loop to pick up the task for review.
```

- [ ] **Step 3: Verify the changes**

Run:
```bash
grep -n "loop mode\|AGENT_LOOP_MODE" .opencode/skills/engineer/SKILL.md
grep -n "pr-ready\|add-label" .opencode/skills/engineer/SKILL.md
```
Expected: Each grep returns at least one matching line

- [ ] **Step 4: Commit**

```bash
git add .opencode/skills/engineer/SKILL.md
git commit -m "feat(skills): add loop mode detection and pr-ready label convention to Engineer skill"
```

---

## Chunk 3: Final Verification

### Task 7: Smoke test the scripts

- [ ] **Step 1: Verify all scripts are executable**

Run: `ls -la scripts/`
Expected: All three scripts (`run-tl-loop.sh`, `run-eng-loop.sh`, `spawn-agents.sh`) have execute permissions

- [ ] **Step 2: Verify TL loop fails correctly without TL_MODEL**

Run: `unset TL_MODEL; bash scripts/run-tl-loop.sh; echo "exit: $?"`
Expected: Error message containing "TL_MODEL env var is not set" and `exit: 1`

- [ ] **Step 3: Verify Engineer loop fails correctly without ENG_MODEL**

Run: `unset ENG_MODEL; bash scripts/run-eng-loop.sh; echo "exit: $?"`
Expected: Error message containing "ENG_MODEL env var is not set" and `exit: 1`

- [ ] **Step 4: Verify spawn-agents fails correctly without models**

Run: `unset TL_MODEL; unset ENG_MODEL; bash scripts/spawn-agents.sh; echo "exit: $?"`
Expected: Error message containing "TL_MODEL and ENG_MODEL must both be set" and `exit: 1`

- [ ] **Step 5: Verify spawn-agents fails if only one model is set**

Run: `unset ENG_MODEL; TL_MODEL=test-model bash scripts/spawn-agents.sh; echo "exit: $?"`
Expected: Same error message and `exit: 1`

- [ ] **Step 6: Verify skill files contain the new sections**

Run:
```bash
grep -n "Team Mode" .opencode/skills/product-owner/SKILL.md
grep -n "loop mode" .opencode/skills/tech-lead/SKILL.md
grep -n "loop mode" .opencode/skills/engineer/SKILL.md
grep -n "needs-tl-review" .opencode/skills/product-owner/SKILL.md
grep -n "needs-engineer" .opencode/skills/tech-lead/SKILL.md
grep -n "pr-ready" .opencode/skills/engineer/SKILL.md
```
Expected: Each grep returns at least one matching line

- [ ] **Step 7: Verify individual mode is unaffected**

The skill changes are purely additive — no existing content was removed. Confirm this by checking that the original Session Start Protocol content still exists in each skill:

```bash
grep -n "Check for GUARDRAILS.md" .opencode/skills/tech-lead/SKILL.md
grep -n "Check for GUARDRAILS.md" .opencode/skills/engineer/SKILL.md
grep -n "ALWAYS use the \`brainstorming\` skill" .opencode/skills/product-owner/SKILL.md
```
Expected: Each grep returns at least one line — the original content is intact.

- [ ] **Step 8: Final commit — commit the spec and plan docs if not already tracked**

Run:
```bash
git status
git add docs/superpowers/
git commit -m "docs: add 3-agent team loop spec and implementation plan"
```

- [ ] **Step 9: Verify clean git status**

Run: `git status`
Expected: Clean working tree
