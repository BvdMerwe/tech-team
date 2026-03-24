#! /bin/bash

# Copy the skills to the .opencode/skills folder here otherwise it won't register the changes
echo "Copying scripts"
cp -r skills ~/.agents

echo "Deleting artifacts and running opencode"
rm -rf .tech-team 2>/dev/null; opencode run "/product-owner" --model opencode/big-pickle