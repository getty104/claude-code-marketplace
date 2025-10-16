GitHubのIssueの内容を確認し、タスクを実行する処理を行なってください。
実行する処理のステップは以下のとおりです。

## git-worktreeの準備
以下のステップでgit-worktreeを準備してください。

1. !`gh issue view $ARGUMENTS` でGitHubのIssueの内容を確認する
2. mainにチェックアウトし、pullを行い、最新のリモートの状態を取得する
3. !`mkdir -p .git-worktrees` でworktree用のディレクトリを作成する
4. Issueの内容を元に、適切な命名でブランチでworktreeを作成する
    - worktreeは`.git-worktrees`ディレクトリに作成してください
    - ブランチ名には`/`を含めないでください
5. `.env`ファイルを作成したworktreeにコピーする
6. `cd`コマンドで作成したworktreeに移動する
7. 移動したworktree内でSerenaのアクティベートを行い、`cp -r ../../.serena/memories .serena/memories`を実行後、オンボーディングを実施する
8. 環境ごとに必要なセットアップ(nodeであればnpm installなど)を実行して、必要なパッケージをインストールする

## Issueの内容確認とタスク遂行
github-issue-implementerサブエージェントを用いて、Issueの内容を確認し、タスクを遂行してください。
なお、タスクはすべて作成したworktree内で行います。
作成したworktree以外の場所で作業を行わず、コードの変更も行わないでください。
`cd`コマンドを利用する場合は`pwd`コマンドで現在のディレクトリを確認し、作成したworktree内であることを確認してください。
