#!/bin/bash

set -e

CURRENT_DIR=$(pwd)

if [[ ! "$CURRENT_DIR" =~ /.claude/worktrees/[^/]+$ ]]; then
    echo "Not in a .claude/worktrees/<dir> directory. Skipping setup."
    exit 0
fi

RANDOM_SUFFIX=$(cat /dev/urandom | LC_ALL=C tr -dc 'a-z0-9' | head -c 8)
BRANCH_NAME="worktree-${RANDOM_SUFFIX}"

git branch "$BRANCH_NAME" main
git symbolic-ref HEAD "refs/heads/$BRANCH_NAME"
git reset --hard main
echo "Switched to new branch from main: $BRANCH_NAME"
