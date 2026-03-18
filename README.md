# Tech Team Skills

A 3-tier AI agent hierarchy for software engineering teams.

```
User Request → Product Owner → Tech Lead → Engineer(s)
```

## Overview

This repository provides a complete engineering team simulation using AI agents with different capabilities and costs:

| Role | Model Tier | Responsibility | Cost |
|------|-----------|----------------|------|
| **Product Owner** | High (expensive) | Brainstorm user needs, create specs | $$$ |
| **Tech Lead** | Mid-to-High | Architecture, task breakdown, code review | $$ |
| **Engineer** | Low (cheap) | Implementation, testing | $ |

## Installation

```bash
# Install all three skills
npx skills add BvdMerwe/tech-team

# Or install individually
npx skills add BvdMerwe/tech-team/product-owner
npx skills add BvdMerwe/tech-team/tech-lead
npx skills add BvdMerwe/tech-team/engineer
```

## The Hierarchy

### 1. Product Owner (PO)
**Skill:** `product-owner`

**When to invoke:** Starting a new feature, understanding user needs

**Workflow:**
1. Brainstorms with user using the `brainstorming` skill
2. Creates feature specifications in `docs/superpowers/specs/`
3. Creates feature-level beads tasks
4. Hands off to Tech Lead

**Key outputs:**
- Feature spec documents (user stories, acceptance criteria)
- Feature tracking in beads

### 2. Tech Lead (TL)
**Skill:** `tech-lead`

**When to invoke:** Managing technical work, reviewing code

**Workflow:**
1. Reviews PO specs for technical feasibility
2. Creates technical tasks from features
3. Assigns work to engineers via beads
4. Reviews all engineer deliverables
5. Enforces quality gates

**Key outputs:**
- Technical tasks with clear requirements
- Code reviews and approvals
- Work coordination through beads

### 3. Engineer
**Skill:** `engineer`

**When to invoke:** Implementing tasks

**Workflow:**
1. Reads `GUARDRAILS.md` for project context (creates if missing)
2. Claims tasks from Tech Lead
3. Implements following project patterns
4. Runs quality gates from GUARDRAILS.md
5. Submits for TL review

**Key outputs:**
- Implemented features
- Passing tests and quality gates
- PRs for review

## Project Guardrails

The Engineer skill requires a `GUARDRAILS.md` file in your project root. This file contains:
- Tech stack and frameworks
- Quality gate commands
- Key file locations
- Common patterns
- Project-specific gotchas

**Example:**
```markdown
# Project Guardrails - MyProject

## Tech Stack
- Framework: Next.js 15 + React 19
- Language: TypeScript
- Database: PostgreSQL
- Testing: Vitest

## Quality Gates
```bash
pnpm lint && pnpm test && pnpm build
```

## Key Commands
| Command | Purpose |
|---------|---------|
| `pnpm dev` | Start dev server |
| `pnpm test` | Run tests |
| `pnpm build` | Production build |

## Key Files
| File | Purpose |
|------|---------|
| `/AGENTS.md` | Project conventions |
| `/src/lib/db.ts` | Database client |

## Common Patterns
**API Route:**
```typescript
// Pattern documentation here
```
```

If GUARDRAILS.md doesn't exist, the Engineer skill will offer to create it by asking you 5 questions about your project.

## Usage Example

**Starting a new feature:**

1. **User:** "I want to add user authentication"

2. **Invoke Product Owner skill:**
   - Brainstorms what "authentication" means
   - Asks about OAuth, email/password, MFA
   - Creates spec document
   - Creates feature bead
   - Hands off to TL

3. **Invoke Tech Lead skill:**
   - Reviews spec for technical feasibility
   - Creates tasks:
     - Set up auth database schema
     - Create login page
     - Implement OAuth flow
   - Assigns to Engineer

4. **Invoke Engineer skill:**
   - Reads GUARDRAILS.md
   - Claims first task
   - Implements following project patterns
   - Runs quality gates
   - Submits for review

5. **Tech Lead reviews** and either approves or requests changes

6. **Cycle continues** until feature is complete

## Communication Protocol

**All communication happens through beads.**

- PO creates feature beads
- TL creates technical tasks
- Engineers report progress
- TL reviews and approves

No ad-hoc communication - everything is tracked.

## Quality Gates

Every task must pass the quality gates specified in GUARDRAILS.md. Typically:
- Lint checks
- Test suite
- Build validation

**No exceptions.** Evidence before approval.

## Design Documents

See the `docs/` directory for detailed design documents:
- `2026-03-18-product-owner-skill-design.md` - PO skill design
- `2026-03-18-tech-lead-skill-design.md` - TL skill design  
- `2026-03-18-generic-engineer-guardrails-design.md` - Engineer skill + GUARDRAILS.md design

## Model Assignment Strategy

**Why different model tiers?**

- **PO (High/$$$):** Needs sophisticated reasoning about user needs, asking good questions, writing clear specs
- **TL (Mid-High/$$):** Needs architecture reasoning, code review capabilities, technical decision making
- **Engineer (Low/$):** Follows clear instructions, implements to spec, reports blockers

This optimizes cost while maintaining quality at each layer.

## Benefits

1. **Clear separation of concerns** - Each role has distinct responsibilities
2. **Cost optimization** - Use expensive models only where needed
3. **Quality control** - TL reviews all work, enforces standards
4. **Reusability** - Same skills work on any project with GUARDRAILS.md
5. **Traceability** - All work tracked through beads

## Related Skills

These skills work well with:
- `brainstorming` - Used by PO for requirement gathering
- `beads` - Task tracking system
- `writing-plans` - For creating implementation plans (TL uses)

## Contributing

To add a new skill to this hierarchy:
1. Create skill in `.opencode/skills/[name]/`
2. Follow the 3-tier model
3. Update this README
4. Commit and push

## License

MIT

---

**Made with love by Bernardus**
