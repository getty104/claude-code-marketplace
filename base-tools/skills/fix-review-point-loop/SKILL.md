---
name: fix-review-point-loop
description: Repeatedly address unresolved review comments until none remain (checks every 5 minutes)
disable-model-invocation: true
argument-hint: "[branch-name]"
model: opus
agent: general-purpose
context: fork
---

# Fix Review Point Loop

Resolveしていないレビューコメントの指摘内容へ対応して下さい。
実行する処理のステップは以下のとおりです。

## git-worktreeの準備

以下のステップでgit-worktreeを準備してください。

1. create-git-worktree skillを用いて$ARGUMENTSで指定されたブランチのgit-worktreeを準備し、環境をセットアップする
2. 作成したworktreeに移動するために、`cd .git-worktrees/$WORKTREE_NAME`を実行する

## 初回のレビューコメント対応

以下のステップでレビューコメントの確認とタスクの遂行を行ってください。

1. Planサブエージェントを用いて、PRの未解決レビューコメントを分析し、修正タスクを洗い出す
2. general-purpose-assistantサブエージェントを用いて、洗い出したタスクを順番に実行する
3. resolve-pr-comments skillを用いて、すべてのレビューコメントをResolveする
4. 修正した内容を元に、PRのdescriptionを最新の状態に更新する
5. `/gemini review`というコメントをPRに追加して、再度レビューを依頼する

## レビューコメントの繰り返し対応

以下の手順を、Resolveされていないレビューコメントが0になるまで繰り返して下さい。

1. pr-review-plannerサブエージェントを用いて、PRの未解決レビューコメントを分析し、修正タスクを洗い出す
2. general-purpose-assistantサブエージェントを用いて、洗い出したタスクを順番に実行する
3. resolve-pr-comments skillを用いて、すべてのレビューコメントをResolveする
4. 修正した内容を元に、PRのdescriptionを最新の状態に更新する
5. `/gemini review`というコメントをPRに追加して、再度レビューを依頼する
6. 5分待つ

## 重要な制約

- タスクはすべて作成したworktree内で行います
- 作成したworktree以外の場所で作業を行わず、コードの変更も行わないでください
- `cd`コマンドを利用する場合は`pwd`コマンドで現在のディレクトリを確認し、作成したworktree内であることを確認してください
