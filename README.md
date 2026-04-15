# Tech Team Skills

Two-agent AI system for software projects. Simple. No complexity demon.

```
User → Grug → Grunk → done
```

## Agents

| Agent | Model tier | Job |
|-------|-----------|-----|
| **Grug** | High (expensive) | Talk user. Write short spec. Review for complexity. |
| **Grunk** | Low (cheap) | Read spec. Plan. Build. Test. Tag pr-ready. |

Both speak caveman in beads to save tokens.

## Install

```bash
npx skills add BvdMerwe/tech-team
```

Or individually:
```bash
npx skills add BvdMerwe/tech-team/grug
npx skills add BvdMerwe/tech-team/grunk
```

## Usage

### Start loops

```bash
GRUG_MODEL=<model> GRUNK_MODEL=<model> bash skills/grug/scripts/spawn-agents.sh
```

Example:
```bash
GRUG_MODEL=anthropic/claude-sonnet-4-5 GRUNK_MODEL=opencode/big-pickle bash skills/grug/scripts/spawn-agents.sh
```

### Use interactively (no loops)

Invoke directly in opencode:
```
/grug   — talk to user, write specs, review work
/grunk  — implement tasks
```

Both work without loops. Loop mode auto-detected via `$AGENT_LOOP_MODE`.

## Agent Configuration

Grug and Grunk ship as configured agents for both OpenCode and Claude.

### OpenCode agents

The repo includes project-level agents in `.opencode/agents/`. They activate automatically when you open the project in OpenCode.

To install globally (works in any project):

```bash
# Copy to your global opencode agents directory
cp .opencode/agents/grug.md ~/.config/opencode/agents/
cp .opencode/agents/grunk.md ~/.config/opencode/agents/
```

**In the TUI:**
- Press **Tab** to switch Grug or Grunk as your primary agent
- Type `@grug` or `@grunk` to invoke as a subagent mid-conversation

**Configuration options** (edit `.opencode/agents/grug.md` or `grunk.md`):

```yaml
---
description: ...     # shown in agent picker
mode: all            # primary + subagent (or: primary, subagent)
model: ...           # override model for this agent
temperature: 0.3
color: "#8B4513"     # color in TUI
permission:
  bash: allow
  edit:
    "GUARDRAILS.md": ask
    "*": allow
---
```

### Claude subagents

For use with Claude Code or as subagents in Claude sessions:

```bash
cp .opencode/agents/grug.md ~/.claude/agents/
cp .opencode/agents/grunk.md ~/.claude/agents/
```

Claude subagents appear in the Task tool and can be invoked by other agents automatically based on their description.

## Label Flow

```
Grug creates task (needs-grunk)
  → Grunk picks up, builds, tags pr-ready
  → Grug reviews: approve (close) or send back (needs-grunk)
```

## Beads Quick Reference

```bash
bd ready                             # find available work
bd show <id> --long                  # read full task
bd update <id> --claim               # claim task
bd update <id> --add-label pr-ready  # mark ready for review
bd close <id> --reason "done"        # close task
bd dolt push                         # sync to remote
```

## GUARDRAILS.md

Grunk reads `GUARDRAILS.md` at project root to understand:
- Tech stack
- Quality gate commands
- Key files and patterns

If missing, Grunk creates it by asking 3 questions.

## How It Works

1. Grug talks to user, understands problem
2. Grug writes short caveman spec in beads (`needs-grunk`)
3. Grunk loop detects task, implements, runs quality gates
4. Grunk tags `pr-ready`, comments brief summary
5. Grug loop detects `pr-ready`, reviews for complexity + obvious mistakes
6. Grug approves (closes) or sends back (`needs-grunk`) with note

## Why Caveman

Both agents write caveman speak in beads comments and descriptions. ~75% fewer tokens. Still accurate.

- Bad: "I have completed the implementation and verified all acceptance criteria are met."
- Good: "grunk done. build X. test pass."

### Optional: caveman skill

For enhanced caveman output, install the [JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman) skill:

```bash
npx skills add JuliusBrussee/caveman
```

Both Grug and Grunk detect it automatically on startup and load it if present. If not installed, they fall back to built-in caveman rules — same low-token output, no extra dependency required.

## Design Docs

See `docs/` for detailed design history.

---

**Made with love by Bernardus**
