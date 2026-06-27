---
name: resolve-pr-conflict
description: 指定されたGitHub PRがターゲットブランチとコンフリクトしていないかを確認し、コンフリクトしている場合はrebaseで解消してforce-pushします。PRをマージ可能な状態に整えたいとき、または`triage-pr`などの上位スキルからコンフリクト確認・解消フェーズだけを切り出して実行したいときに使用してください。
argument-hint: "[pr-number]"
---

# Resolve PR Conflict

指定されたPR番号のPRがターゲットブランチ（`baseRefName`）とコンフリクトしていないかを確認し、コンフリクトがあればrebaseで解消したうえで`--force-with-lease`でpushするスキルです。

このスキルは`triage-pr`の「コンフリクト確認・解消フェーズ」のみを切り出したもので、レビュー指摘の対応・修正プランの評価・ラベル付与・マージ判定といった`triage-pr`の他の責務には立ち入らない。

## このスキルがやること・やらないこと

**やること**:
- `gh pr checkout`によるPRブランチへの切り替え
- ターゲットブランチとのコンフリクト有無の判定
- コンフリクトがある場合のrebase実行・コンフリクト解消・`--force-with-lease`でのpush

**絶対にやらないこと**:
- コンフリクト解消以外の目的でのコード変更（リファクタリング、レビュー指摘対応、Lint修正、テスト追加など）
- rebase以外での新規commit作成（`git commit`単体での新規commitは作らない）
- PRへのラベル付与・コメント投稿・マージ・close（上位スキルの責務）
- `git push --force`（`--force-with-lease`以外のforce-push）

# Instructions

`$ARGUMENTS`がPR番号を表す。空・非数値・複数値の場合は、その旨を出力して即中断する。

## ステップ0: 作業ディレクトリの安全確認

このスキルは単独でも `triage-pr` 等からの委譲でも起動される。いずれのケースでも、呼び出し元の作業コンテキストを尊重するため、現在地を変更しない・新規worktreeを作らないことを徹底する。

```bash
pwd
```

判定:

- **`.claude/worktrees/` 配下にいる場合**: そのworktree内で全ての作業（`gh pr checkout` / `git rebase` / `git push`）を完結させる。`cd`でworktreeの外に出たり、リポジトリのルートに移動したりしない。新規worktreeも作らない（呼び出し元が用意したworktreeのコンテキストを破壊しないため）
- **`.claude/worktrees/` 配下にいない場合（リポジトリのルート・通常のクローン等）**: その場で作業する。`.claude/worktrees/` 配下に移動したり、新規worktreeを作成したりはしない

加えて、デフォルトブランチで直接rebase / force-pushを行う事故を避けるため、`gh pr checkout` の **直後**（ステップ1）で現在ブランチがデフォルトブランチと一致しないことを確認する（一致した場合は中断する）。

## ステップ1: PRの存在確認とチェックアウト

まずPRが存在し、コンフリクト解消の対象として妥当な状態かを確認する。

```bash
gh pr view $ARGUMENTS --json number,state,baseRefName,headRefName
```

`state`が`OPEN`以外（`MERGED` / `CLOSED`）の場合や、PR自体が存在しない場合は、その旨を出力して中断する。CLOSED/MERGED済みのPRに対してforce-pushを行うのは無意味であり、誤操作のリスクの方が大きいため。

存在を確認できたら、PRブランチをチェックアウトする。ステップ0で確認したとおり、現在地（worktree内 or 通常クローン）でそのまま実行し、新規worktreeは作らない。

```bash
git fetch -p
gh pr checkout $ARGUMENTS
```

`gh pr checkout`が失敗した場合（作業ツリーが汚れている、ローカルに同名のブランチがある等）は、原因をそのまま出力して中断する。`git stash`や`git reset --hard`を独断で行ってユーザーの未コミット変更を失わせないこと。

チェックアウト成功後、fail-safeとしてブランチがデフォルトブランチでないことを確認する。

```bash
DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
```

`CURRENT_BRANCH`が`DEFAULT_BRANCH`と一致する場合は中断する（通常`gh pr checkout`後にPRブランチへ切り替わるため一致しないはずだが、想定外の状態でrebase/force-pushがデフォルトブランチに走るのを防ぐため）。`gh repo view`が失敗してデフォルトブランチ名が取得できない場合も、判定不能として中断する。

## ステップ2: ターゲットブランチとのコンフリクト判定

PRのターゲットブランチを`baseRefName`から動的に取得する。デフォルトブランチではなく、PRが実際にマージされる先のブランチを基準にすること（Epic PRなど、デフォルトブランチ以外をターゲットにするケースに対応するため）。

```bash
TARGET_BRANCH=$(gh pr view $ARGUMENTS --json baseRefName -q .baseRefName)
git merge-tree $(git merge-base HEAD "origin/$TARGET_BRANCH") HEAD "origin/$TARGET_BRANCH"
```

判定基準: `git merge-tree`の標準出力にコンフリクトマーカー（`<<<<<<<` / `=======` / `>>>>>>>`）が含まれていれば「コンフリクトあり」、含まれていなければ「コンフリクトなし」。

### コンフリクトなしの場合

「コンフリクトなし」を呼び出し元に返却して終了する。`git rebase`も`push`も行わない。不要なrebase/force-pushはCIを無駄に再走させ、他者がそのブランチを見ているときの混乱の元になるため、何もしないのが正解。

### コンフリクトありの場合

ステップ3に進む。

## ステップ3: rebaseによるコンフリクト解消

ターゲットブランチに対してrebaseを実行する。

```bash
git rebase "origin/$TARGET_BRANCH"
```

rebase中にコンフリクトが発生した場合は、`git status`でコンフリクト中のファイルを特定し、それぞれを **両者の変更意図を尊重する形** で解消する。片方の変更を機械的に捨てると、PR側のレビュー意図かターゲットブランチ側の最新仕様のどちらかを取りこぼすため、必要に応じて以下を行ってから解消する。

- `Read`で該当ファイル全体を読み、コンフリクトしている関数/ブロックの責務を理解する
- `git log -p`でターゲットブランチ側・PR側それぞれの該当変更commitを確認し、変更意図を読み取る
- 周辺コードや関連テストを`Read` / `Grep`で参照し、整合性のとれた解消にする

判断できない場合（情報が足りない、両方が同じ箇所を大きく書き換えている、人間の仕様判断が必要、など）は無理に解消せず、`git rebase --abort`で取り消したうえで中断理由を呼び出し元に返却する。生半可な解消はレビューで差し戻されるか、最悪本番バグの混入につながるため。

解消後：

```bash
git add <解消したファイル>
git rebase --continue
```

複数commitにまたがって連続してコンフリクトする場合は、各commitで同じ手順を最後まで繰り返す。

## ステップ4: force-push

rebase完了後、リモートに反映する。

```bash
git push origin HEAD --force-with-lease
```

`--force-with-lease`を使うのは、自分の認識していないリモートの新規commitを上書きしないため（他人のpushを巻き戻すリスクを避ける）。pushが失敗した場合は、エラー内容をそのまま呼び出し元に返却して中断する。自動再試行はしない（再試行が必要なケースは、リモートに新規pushが来ているなど人間判断が必要な状況のため）。

## 出力

呼び出し元には以下を構造化して返却する。

- **判定**: `no-conflict` / `resolved-and-pushed` / `aborted` のいずれか
- **詳細**:
  - `no-conflict`: ターゲットブランチ名
  - `resolved-and-pushed`: 解消したファイル一覧と各ファイルの解消方針の要点
  - `aborted`: 中断理由（PRがOPENでない / checkout失敗 / コンフリクト解消困難 / push失敗 など）と、その時点のgitの状態（`git status`の要約）

## 注意事項

- このスキルは **コンフリクト解消のみ** を目的とする。スコープ外の修正（Lint対応、テスト追加、リファクタリング、レビュー指摘対応）は行わない
- ステップ3のrebase中の`Edit` / `Write`以外でコードを変更しないこと。コンフリクトと無関係な「ついで修正」を入れると、後続のレビューと履歴が複雑になる
- **作業ディレクトリを動かさない**: `.claude/worktrees/` 配下で起動された場合は絶対にworktreeの外に出ない（`cd ..`やリポジトリのルートへの移動禁止）。新規worktreeも作らない。worktree外で起動された場合も、勝手にworktreeに移動しない。呼び出し元（`triage-pr`や直接実行したユーザー）が用意した作業コンテキストを尊重するため
- **デフォルトブランチで作業しない**: `gh pr checkout` 後にHEADがデフォルトブランチと一致する場合は中断する。デフォルトブランチ上でrebase / force-pushが走ると共有ブランチを破壊する事故につながる
- PRに付与されているラベル（`cc-triage-scope`等を含む）は一切操作しない。ラベル管理は上位スキルの責務
- `git push --force`は使わず、必ず`--force-with-lease`を使う
- コンフリクトなしの場合は何もせず終了する。不要なrebase / force-pushを発生させない
