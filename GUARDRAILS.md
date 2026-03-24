# Project Guardrails - tech-team

## Tech Stack
- Language: Bash scripts, Markdown
- Task Tracking: beads (Dolt-powered issue tracker)
- Agent Framework: opencode
- Package Manager: None (script repository)
- Testing: bash -n syntax checks

## Quality Gates
```bash
# Check bash syntax for all shell scripts
find . -name "*.sh" -exec bash -n {} \;
```

## Key Commands
| Command | Purpose |
|---------|---------|
| `bd ready` | Find available work |
| `bd show <id>` | View issue details |
| `bd update <id> --claim` | Claim work atomically |
| `bd close <id>` | Complete work |
| `bd dolt push` | Sync to remote |

## Key Files
| File | Purpose |
|------|---------|
| `/AGENTS.md` | Project conventions for agents |
| `/README.md` | Project overview |
| `/skills/*/SKILL.md` | Agent skill definitions |
| `/.tech-team/*.sh` | Agent loop runner scripts |
| `/scripts/*.sh` | Utility scripts |
| `/docs/*.md` | Design documents |

## Common Patterns

### Skill File Format
Skills use YAML frontmatter + Markdown body:
```yaml
---
name: skill-name
description: What the skill does
location: path/to/SKILL.md
---
# Skill Content

Rest of skill documentation...
```

### Agent Loop Scripts
The `.tech-team/` scripts orchestrate agent loops:
- `run-eng-loop.sh` - Runs the Engineer agent loop
- `run-tl-loop.sh` - Runs the Tech Lead agent loop
- `spawn-agents.sh` - Spawns multiple agents

## Project-Specific Gotchas
1. This is a script/markdown repo - no npm/yarn/pnpm
2. Quality gates use bash -n for syntax checking only
3. Task IDs follow pattern: tech-team-XXXX
4. All shell scripts should pass `bash -n` before commit

## Branch Strategy
- **main** - Production-ready
- Feature branches follow git conventions

## Communication
- Task tracking: beads (issue IDs like tech-team-XXXX)
- All agents use `bd` for task management
