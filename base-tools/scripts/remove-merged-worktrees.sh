#!/bin/bash

set -e

git fetch --prune

DEFAULT_BRANCH="origin/HEAD"

while IFS= read -r line; do
    WORKTREE_PATH=$(echo "$line" | awk '{print $1}')
    BRANCH=$(echo "$line" | awk '{print $3}' | sed 's/^\[//' | sed 's/\]$//')

    if [ -z "$BRANCH" ] || [ "$BRANCH" = "(bare)" ]; then
        continue
    fi

    if echo "$BRANCH" | grep -qE '^(main|master|develop)$'; then
        continue
    fi

    BRANCH_POINT=$(git merge-base "$DEFAULT_BRANCH" "$BRANCH" 2>/dev/null || true)
    BRANCH_HEAD=$(git rev-parse "$BRANCH" 2>/dev/null || true)

    if [ -z "$BRANCH_POINT" ] || [ -z "$BRANCH_HEAD" ]; then
        continue
    fi

    if [ "$BRANCH_POINT" = "$BRANCH_HEAD" ]; then
        echo "Skipping '$BRANCH' - no commits yet (branch point equals HEAD)"
        continue
    fi

    if ! git branch --merged "$DEFAULT_BRANCH" | sed 's/^[*+ ]*//' | grep -qx "$BRANCH"; then
        echo "Skipping '$BRANCH' - not merged to main"
        continue
    fi

    if [ -n "$(git -C "$WORKTREE_PATH" status --porcelain 2>/dev/null)" ]; then
        echo "Skipping '$BRANCH' - has uncommitted changes"
        continue
    fi

    echo "Removing merged worktree: $WORKTREE_PATH ($BRANCH)"
    git worktree remove "$WORKTREE_PATH"
done < <(git worktree list | tail -n +2)

echo "Cleaning up merged branches without worktrees..."
MERGED_BRANCHES=$(git branch --merged "$DEFAULT_BRANCH" | sed 's/^[*+ ]*//' | grep -v -E '^(main|master|develop)$' || true)

if [ -n "$MERGED_BRANCHES" ]; then
    while IFS= read -r branch; do
        HAS_WORKTREE=$(git worktree list --porcelain | awk -v branch="$branch" '
            /^worktree / { path = substr($0, 10) }
            /^branch / {
                ref = substr($0, 8)
                if (ref == "refs/heads/" branch) {
                    print "yes"
                    exit
                }
            }
        ')

        if [ -z "$HAS_WORKTREE" ]; then
            echo "Deleting merged branch: $branch"
            git branch -d "$branch"
        fi
    done <<< "$MERGED_BRANCHES"
fi

echo "Done."
