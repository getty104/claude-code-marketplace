#!/bin/bash

git fetch --prune

# mainブランチ(またはmaster)にmerge済みのブランチを取得
MERGED_BRANCHES=$(git branch --merged main | grep -v "^\*" | grep -v "main" | grep -v "master")

# 各worktreeをチェックして削除
git worktree list | tail -n +2 | while read -r line; do
    WORKTREE_PATH=$(echo "$line" | awk '{print $1}')
    WORKTREE_BRANCH=$(echo "$line" | awk '{print $3}' | tr -d '[]')

    # merge済みのブランチかチェック
    if echo "$MERGED_BRANCHES" | grep -q "^[[:space:]]*${WORKTREE_BRANCH}$"; then
        echo "Removing worktree: $WORKTREE_PATH ($WORKTREE_BRANCH)"
        git worktree remove "$WORKTREE_PATH"
    fi
done
