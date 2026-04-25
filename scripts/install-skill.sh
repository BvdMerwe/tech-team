#!/bin/bash
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

./scripts/init-scripts.sh

AGENT_SKILL_TARGET=$REPO_ROOT/.agents/skills
OPENCODE_SKILL_TARGET=$REPO_ROOT/.opencode/skills
GRUG_SKILL_SOURCE=skills/grug/.
GRUNK_SKILL_SOURCE=skills/grunk/.


mkdir -p $AGENT_SKILL_TARGET
cp -f -R $GRUG_SKILL_SOURCE $AGENT_SKILL_TARGET/grug/
cp -f -R $GRUNK_SKILL_SOURCE $AGENT_SKILL_TARGET/grunk/

mkdir -p $OPENCODE_SKILL_TARGET
cp -f -R $GRUG_SKILL_SOURCE $OPENCODE_SKILL_TARGET/grug/
cp -f -R $GRUNK_SKILL_SOURCE $OPENCODE_SKILL_TARGET/grunk/

echo "Installed skills locally."