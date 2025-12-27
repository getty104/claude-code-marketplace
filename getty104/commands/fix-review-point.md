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
review-comment-implementerサブエージェントを用いて、Resolveしていないレビューコメントの指摘内容へ対応して下さい。
なお、タスクはすべて作成したworktree内で行います。
作成したworktree以外の場所で作業を行わず、コードの変更も行わないでください。
`cd`コマンドを利用する場合は`pwd`コマンドで現在のディレクトリを確認し、作成したworktree内であることを確認してください。
