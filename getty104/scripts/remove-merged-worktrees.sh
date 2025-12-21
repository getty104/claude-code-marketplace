#!/bin/bash

set -e

git fetch --prune

MERGED_BRANCHES=$(git branch --merged origin/main | sed 's/^[*+ ]*//' | grep -v -E '^(main|master)$' || true)

if [ -z "$MERGED_BRANCHES" ]; then
    echo "No merged branches found."
    exit 0
fi

while IFS= read -r branch; do
    UNIQUE_COMMITS=$(git log origin/main.."$branch" --oneline 2>/dev/null || true)

    if [ -n "$UNIQUE_COMMITS" ]; then
        echo "Skipping branch '$branch' - has unique commits not yet merged to main"
        continue
    fi

    WORKTREE_PATH=$(git worktree list --porcelain | awk -v branch="$branch" '
        /^worktree / { path = substr($0, 10) }
        /^branch / {
            ref = substr($0, 8)
            if (ref == "refs/heads/" branch) {
                print path
                exit
            }
        }
    ')

    if [ -n "$WORKTREE_PATH" ]; then
        echo "Removing worktree: $WORKTREE_PATH ($branch)"
        git worktree remove "$WORKTREE_PATH"
    fi
done <<< "$MERGED_BRANCHES"
