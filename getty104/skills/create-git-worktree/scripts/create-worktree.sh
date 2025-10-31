#!/bin/bash

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <branch-name>"
    echo "Example: $0 feature/new-feature"
    exit 1
fi

BRANCH_NAME="$1"
WORKTREE_NAME=$(echo "$BRANCH_NAME" | tr '/' '-')
WORKTREE_PATH=".git-worktrees/$WORKTREE_NAME"
REPO_ROOT=$(git rev-parse --show-toplevel)

echo "Creating worktree for branch: $BRANCH_NAME"
echo "Worktree path: $WORKTREE_PATH"

cd "$REPO_ROOT"

git checkout main
git pull

mkdir -p .git-worktrees

if [ -d "$WORKTREE_PATH" ]; then
    echo ""
    echo "✓ Worktree already exists at: $WORKTREE_PATH"
    echo ""
    echo "Next steps:"
    echo "1. cd $WORKTREE_PATH"
    echo "2. Continue working on your task"
    echo ""
    exit 0
fi

if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
    git worktree add "$WORKTREE_PATH" "$BRANCH_NAME"
else
    git worktree add -b "$BRANCH_NAME" "$WORKTREE_PATH"
fi

if [ -f .env ]; then
    cp .env "$WORKTREE_PATH/.env"
    echo "Copied .env file to worktree"
fi

cd "$WORKTREE_PATH"

if [ -d "$REPO_ROOT/.serena" ]; then
    mkdir -p .serena
    if [ -d "$REPO_ROOT/.serena/memories" ]; then
        cp -r "$REPO_ROOT/.serena/memories" .serena/memories
        echo "Copied Serena memories to worktree"
    fi
fi

if [ -f package.json ]; then
    echo "Installing npm dependencies..."
    npm install
fi

echo ""
echo "✓ Worktree created successfully!"
echo ""
echo "Next steps:"
echo "1. cd $WORKTREE_PATH"
echo "2. Activate Serena and complete onboarding if needed"
echo "3. Start working on your task"
echo ""
echo "When done, don't forget to run 'docker compose down' if using Docker"
