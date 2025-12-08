---
allowed-tools: Bash(mkdir *), Bash(gh issue view *), Bash(cp *), Bash(cd *), Bash(pwd), Bash(git *), Serena(*), Context7(*)
description: Execute tasks based on GitHub Issue content using a git worktree
---

GitHubのIssueの内容を確認し、タスクを実行する処理を行なってください。
実行する処理のステップは以下のとおりです。

## git-worktreeの準備
以下のステップでgit-worktreeを準備してください。

1. !`gh issue view $ARGUMENTS` でGitHubのIssueの内容を確認する
2. create-git-worktree skillを用いてgit worktreeを作成し、環境のセットアップを行う
    - Issueの内容を元に、適切なブランチ名を決定する
3. 作成したworktreeに移動するために、`cd .git-worktrees/ブランチ名`で移動する
4. 移動したworktree内でSerenaのアクティベートを行い、オンボーディングを実施する

## Issueの内容確認とタスク遂行
github-issue-implementerサブエージェントを用いて、Issueの内容を確認し、タスクを遂行してください。
なお、タスクはすべて作成したworktree内で行います。
作成したworktree以外の場所で作業を行わず、コードの変更も行わないでください。
`cd`コマンドを利用する場合は`pwd`コマンドで現在のディレクトリを確認し、作成したworktree内であることを確認してください。
