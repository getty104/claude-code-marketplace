Resolveしていないレビューコメントの指摘内容へ対応して下さい。
実行する処理のステップは以下のとおりです。

## git-worktreeの準備
以下のステップでgit-worktreeを準備してください。

1. `git checkout main`
2. `git pull origin main`
3. `git fetch`
4. `mkdir -p .git-worktrees`
5. `WORKTREE_NAME="$(echo "$ARGUMENTS" | tr '/' '-')"`でworktree名を準備する
6. `git worktree list`で`$WORKTREE_NAME`という名前のworktreeが存在するかを確認する
7. worktreeが存在しない場合は、`git worktree add .git-worktrees/$WORKTREE_NAME $ARGUMENTS` で新しいworktreeを作成する
    - `.env`ファイルを作成したworktreeにコピーする
8. 作成したworktreeに移動するために、`cd .git-worktrees/$WORKTREE_NAME`を実行する
9. 移動したworktree内でSerenaのアクティベートを行い、`cp -r ../../.serena/memories .serena/memories`を実行後、オンボーディングを実施する
10. 環境ごとに必要なセットアップ(nodeであればnpm installなど)を実行して、必要なパッケージをインストールする

## レビューコメントの確認とタスクの遂行
review-comment-implementerサブエージェントを用いて、Resolveしていないレビューコメントの指摘内容へ対応して下さい。
なお、タスクはすべて作成したworktree内で行います。
作成したworktree以外の場所で作業を行わず、コードの変更も行わないでください。
`cd`コマンドを利用する場合は`pwd`コマンドで現在のディレクトリを確認し、作成したworktree内であることを確認してください。
