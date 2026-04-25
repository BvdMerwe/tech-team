# Test: Create Worktree Flow Bead

Use this prompt to create a test bead for validating the full grug+grunk worktree workflow.

## Prompt

Run this command:

```bash
BD_ACTOR="Grug" bd create "test worktree flow" \
  -t task -p 2 \
  --labels needs-grunk \
  --description "test bead for worktree flow. grunk open branch, do trivial change, tag pr-ready. grug pick up, review, pretend merge, delete branch, close." \
  --acceptance "- [ ] grunk open worktree branch grunk/[id]-test-worktree-flow
- [ ] grunk make trivial commit (e.g. add comment to README)
- [ ] grunk tag pr-ready
- [ ] grug pick up, review, merge branch to main, delete branch, close bead"
```

## Expected Result

- New bead created with label `needs-grunk`
- Grunk loop picks it up, creates worktree, makes trivial commit, tags `pr-ready` (removes `needs-grunk`)
- Grug loop picks it up, reviews, merges branch to main, closes bead
