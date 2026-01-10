---
allowed-tools: Bash(mkdir *), Bash(gh issue view *), Bash(cp *), Bash(cd *), Bash(pwd), Bash(git *), Context7(*)
description: Address unresolved review comments on specified branch
---

Resolveしていないレビューコメントの指摘内容へ対応して下さい。
実行する処理のステップは以下のとおりです。

## git-worktreeの準備

以下のステップでgit-worktreeを準備してください。

1. create-git-worktree skillを用いて${ARGUMENTS}で指定されたブランチのgit-worktreeを準備し、環境をセットアップする
2. 作成したworktreeに移動するために、`cd .git-worktrees/$WORKTREE_NAME`を実行する

## レビューコメントの確認とタスクの遂行

以下のステップでレビューコメントの確認とタスクの遂行を行ってください。

1. pr-review-plannerサブエージェントを用いて、PRの未解決レビューコメントを分析し、修正タスクを洗い出す
2. general-purpose-assistantサブエージェントを用いて、洗い出したタスクを順番に実行する
3. タスクの実行が完了したら、high-quality-commit skillを用いて、変更内容を適切にコミットし、pushする
4. resolve-pr-comments skillを用いて、すべてのレビューコメントをResolveする
5. 修正した内容を元に、PRのdescriptionを最新の状態に更新する
6. `/gemini review`というコメントをPRに追加して、再度レビューを依頼する

## 重要な制約

- タスクはすべて作成したworktree内で行います
- 作成したworktree以外の場所で作業を行わず、コードの変更も行わないでください
- `cd`コマンドを利用する場合は`pwd`コマンドで現在のディレクトリを確認し、作成したworktree内であることを確認してください
