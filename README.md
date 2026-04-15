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

## Design Docs

See `docs/` for detailed design history.

---

**Made with love by Bernardus**
