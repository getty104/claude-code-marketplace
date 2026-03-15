#!/bin/bash

set -e

CURRENT_DIR=$(pwd)

if [[ ! "$CURRENT_DIR" =~ /.claude/worktrees/[^/]+$ ]]; then
    echo "Not in a .claude/worktrees/<dir> directory. Skipping setup."
    exit 0
fi

ROOT_DIR="$(cd "../../../" && pwd)"

if [ -f "$ROOT_DIR/.env" ]; then
    cp "$ROOT_DIR/.env" .env
    echo "Copied .env"
fi
