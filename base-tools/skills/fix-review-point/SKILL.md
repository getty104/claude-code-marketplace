---
name: fix-review-point
description: Address unresolved review comments on specified branch
argument-hint: "[branch-name]"
model: opus
---

# Fix Review Point

Resolveしていないレビューコメントの指摘内容へ対応して下さい。

# Instructions

## 実行ステップ

実行する処理のステップは以下のとおりです。

### 1. git-worktreeの準備

以下のステップでgit-worktreeを準備してください。

1. create-git-worktree skillを用いて$ARGUMENTSで指定されたブランチのgit-worktreeを準備し、環境をセットアップする
2. 作成したworktreeに移動するために、`cd .git-worktrees/$WORKTREE_NAME`を実行する

### 2. レビューコメントの確認とタスクの遂行

以下のステップでレビューコメントの確認とタスクの遂行を行ってください。

1. read-unresolved-pr-comments skillを用いてPRの未解決レビューコメントから修正プランを確認する
2. 洗い出したタスクごとにgeneral-purpose-assistantサブエージェントで実装を行う
3. 全ての実装が完了したら、general-purpose-assistantサブエージェントでテスト・Lintが全て通過することを確認する
  - 問題があれば修正を行う
4. commit-push skillを用いて、変更内容を適切にコミットし、pushする
5. resolve-pr-comments skillを用いて、すべてのレビューコメントをResolveする
6. 修正した内容を元に、PRのdescriptionを最新の状態に更新する
7. `/gemini review`というコメントをPRに追加して、再度レビューを依頼する

## 重要な制約

- タスクはすべて作成したworktree内で行います
- 作成したworktree以外の場所で作業を行わず、コードの変更も行わないでください
- `cd`コマンドを利用する場合は`pwd`コマンドで現在のディレクトリを確認し、作成したworktree内であることを確認してください
