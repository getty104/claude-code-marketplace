---
name: exec-issue
description: Execute tasks based on GitHub Issue content using a git worktree
argument-hint: "[issue-number]"
model: opus
---

# Execute Issue

GitHubのIssueの内容を確認し、タスクを実行する処理を行なってください。
実行する処理のステップは以下のとおりです。

## git-worktreeの準備

以下のステップでgit-worktreeを準備してください。

1. read-github-issue skillを用いて対象のIssueの内容を取得する
  - Issue番号: $ARGUMENTS
2. create-git-worktree skillを用いてgit worktreeを作成し、環境のセットアップを行う
    - Issueの内容を元に、適切なブランチ名を決定する
    - ブランチ名には`/`は使用しないでください
3. 作成したworktreeに移動するために、`cd .git-worktrees/ブランチ名`で移動する

## Issueの内容確認とタスク遂行

以下のステップでIssueの内容に合わせたタスクの遂行、PRの作成を行ってください。

1. read-github-issue skillを用いて対象のIssueの内容と実装プランを確認し、修正タスクを洗い出す
2. 洗い出したタスクごとにgeneral-purpose-assistantサブエージェントを呼び出し、順番に実行する
3. 全てのタスクが完了したら、high-quality-commit skillを用いて、変更内容を適切にコミットする
4. create-pr skillを用いて、変更内容を反映したPRを作成する
5. PRのURLを報告する

## 重要な制約

- タスクはすべて作成したworktree内で行います
- 作成したworktree以外の場所で作業を行わず、コードの変更も行わないでください
- `cd`コマンドを利用する場合は`pwd`コマンドで現在のディレクトリを確認し、作成したworktree内であることを確認してください
