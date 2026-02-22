#!/bin/bash

set -e

CURRENT_DIR=$(pwd)

if [[ ! "$CURRENT_DIR" =~ /.claude/worktrees/[^/]+$ ]]; then
    echo "Not in a .claude/worktrees/<dir> directory. Skipping removal."
    exit 0
fi

wt_path=$(pwd) && cd ../../.. && git worktree remove "$wt_path"
echo "Removed worktree: $wt_path"
