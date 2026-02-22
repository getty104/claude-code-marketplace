#!/bin/bash

set -e

CURRENT_DIR=$(pwd)

if [[ ! "$CURRENT_DIR" =~ /.claude/worktrees/[^/]+$ ]]; then
    echo "Not in a .claude/worktrees/<dir> directory. Skipping removal."
    exit 0
fi

cd ../../..
git worktree remove "$CURRENT_DIR" --force
echo "Removed worktree: $CURRENT_DIR"
