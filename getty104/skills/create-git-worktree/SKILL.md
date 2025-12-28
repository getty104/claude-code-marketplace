---
name: create-git-worktree
description: git worktree を利用した分離作業環境を自動構築します。デフォルトブランチから最新コードを取得し、.git-worktrees/ ディレクトリに新規worktreeを作成、.env・npm依存関係を自動セットアップします。ブランチ名の '/' は自動的に '-' に変換されます。既存worktreeは再利用されます。
---

# Create Git Worktree and Setup Environment

## Instructions
scripts/create-worktree.sh スクリプトは、指定されたブランチ名に基づいて.git-worktrees/ディレクトリに新しいgit worktreeを作成し、.envファイルのコピーとnpm依存関係のインストールを自動的に行います。
このスクリプトを実行することで、分離された作業環境が簡単に構築されます。
