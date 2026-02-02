---
name: exec-issue
description: Execute tasks based on GitHub Issue content using a git worktree
argument-hint: "[issue-number]"
model: opus
---

# Execute Issue

GitHubのIssueの内容を確認し、タスクを実行する処理を行なってください。

# Instructions

## 実行ステップ

### 1. git-worktreeの準備

以下のステップでgit-worktreeを準備してください。

1. create-git-worktree skillを用いてgit worktreeを作成し、環境のセットアップを行う
  - Issueの内容を元に、適切なブランチ名を決定する
  - ブランチ名には`/`は使用しないでください
2. 作成したworktreeに移動するために、`cd .git-worktrees/ブランチ名`で移動する

### 2. Issueの内容確認とタスク遂行

以下のステップでIssueの内容に合わせたタスクの遂行、PRの作成を行ってください。

1. read-github-issue skillを用いて対象のIssueの内容の実装プランを確認する
2. 洗い出したタスクごとに実装を行う
3. 全て実装が完了したら、commit-push skillを用いて、変更内容を適切にコミットし、pushする
4. create-pr skillを用いて、変更内容を反映したPRを作成する
5. PRのURLを報告する

## 重要な制約

- タスクはすべて作成したworktree内で行います
- 作成したworktree以外の場所で作業を行わず、コードの変更も行わないでください
- `cd`コマンドを利用する場合は`pwd`コマンドで現在のディレクトリを確認し、作成したworktree内であることを確認してください
