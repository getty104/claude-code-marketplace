---
name: resolve-pr-conflict
description: 指定されたGitHub PRがターゲットブランチとコンフリクトしていないかを確認し、コンフリクトしている場合はrebaseで解消してforce-pushします。PRをマージ可能な状態に整えたいときに使用してください。
argument-hint: "[pr-number]"
---

# Resolve PR Conflict

指定されたPR番号のPRがターゲットブランチ（`baseRefName`）とコンフリクトしていないかを確認し、コンフリクトがあればrebaseで解消したうえで`--force-with-lease`でpushするスキルです。レビュー指摘の対応・修正プランの評価・ラベル付与・マージ判定といった他の責務には立ち入らない。

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

## 実行モードの制約: サブエージェント・サブスキル・Bashをバックグラウンド実行しないこと

本スキルは `claude-task-worker` の `resolve-conflict` ワーカー（`cc-resolve-conflict` ラベル）から自動起動される想定。ワーカーはスキルプロセスの同期完了を根拠に `cc-resolve-conflict` の除去を進めるため、バックグラウンド化するとrebase未完了のまま `triage-pr` ワーカーが再度PRを拾ってコンフリクトを再検知する無限ループや、リモート未反映のまま次工程に進む状態壊れが起きる。内部処理はすべて同期実行で完結させること。

- **`Agent` ツールは既定が `run_in_background: true`（バックグラウンド）**。呼び出しごとに **必ず `run_in_background: false` を明示指定** し、フォアグラウンドで同期的に結果を受け取ってから次の処理に進む。指定を省略した場合はバックグラウンドで走り、本スキルが未完のまま終了する
- `Skill` / `Bash` ツール呼び出し時に `run_in_background: true` を指定しない（既定は同期）。特に `git rebase` / `git push --force-with-lease` は同期実行で完了を確認してから完了報告する
- シェルコマンド末尾に `&` を付けない。`nohup` / `disown` / `setsid` でのデタッチ、`ScheduleWakeup` 等での後回しも禁止
- 同一メッセージ内で複数の `Agent` / `Skill` を並列に投げるのは「並列実行」であって「バックグラウンド実行」ではないため許容される（各完了はその場で同期的に待つ）

`$ARGUMENTS`がPR番号を表す。空・非数値・複数値の場合は、その旨を出力して即中断する。

## ステップ0: 作業ディレクトリの安全確認

このスキルは単独でも `triage-pr` 等からの委譲でも起動される。いずれのケースでも、呼び出し元が用意した作業コンテキストを尊重するため、現在地を変更しない・新規worktreeを作らないことを徹底する。

```bash
pwd
```

判定:

- **`.claude/worktrees/` 配下にいる場合**: そのworktree内で全ての作業（`gh pr checkout` / `git rebase` / `git push`）を完結させる。`cd`でworktreeの外やリポジトリのルートに移動しない。新規worktreeも作らない
- **`.claude/worktrees/` 配下にいない場合（リポジトリのルート・通常のクローン等）**: その場で作業する。`.claude/worktrees/` 配下への移動や新規worktree作成はしない

加えて、デフォルトブランチで直接rebase / force-pushを行う事故を避けるため、`gh pr checkout` の **直後**（ステップ1）で現在ブランチがデフォルトブランチと一致しないことを確認する（一致した場合は中断する）。

## ステップ1: PRの存在確認とチェックアウト

まずPRが存在し、コンフリクト解消の対象として妥当な状態かを確認する。

```bash
gh pr view $ARGUMENTS --json number,state,baseRefName,headRefName
```

`state`が`OPEN`以外（`MERGED` / `CLOSED`）の場合や、PR自体が存在しない場合は、その旨を出力して中断する（CLOSED/MERGED済みPRへのforce-pushは無意味で誤操作リスクの方が大きいため）。

存在を確認できたら、現在地でそのままPRブランチをチェックアウトする（新規worktreeは作らない）。

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

`CURRENT_BRANCH`が`DEFAULT_BRANCH`と一致する場合は中断する（想定外の状態でrebase/force-pushがデフォルトブランチに走るのを防ぐため）。`gh repo view`が失敗してデフォルトブランチ名が取得できない場合も、判定不能として中断する。

## ステップ2: ターゲットブランチとのコンフリクト判定

PRのターゲットブランチを`baseRefName`から動的に取得する。デフォルトブランチではなく、PRが実際にマージされる先のブランチを基準にすること（Epic PRなど、デフォルトブランチ以外をターゲットにするケースに対応するため）。

コンフリクト有無の一次判定には、呼び出し元の`triage-pr`と同じGitHubの`mergeable`フィールドを使う。判定基準を呼び出し元と揃えないと、「`triage-pr`はコンフリクトありと判定したのに本スキルはなしと判定して何もせず終了する」という食い違いが起き、`cc-resolve-conflict`ラベルの付与と除去が繰り返される無限ループになる。

```bash
TARGET_BRANCH=$(gh pr view $ARGUMENTS --json baseRefName -q .baseRefName)
MERGEABLE=$(gh pr view $ARGUMENTS --json mergeable -q .mergeable)
```

判定基準:

- **`CONFLICTING`**: コンフリクトありと判定し、ステップ3に進む
- **`MERGEABLE`**: コンフリクトなしと判定する
- **`UNKNOWN`**: GitHub側で判定中のため、数秒スリープして1回だけ再取得する。それでも`UNKNOWN`の場合は、ローカルで実マージ相当の判定にフォールバックする

  ```bash
  git merge-tree --write-tree "origin/$TARGET_BRANCH" HEAD
  ```

  終了コードが`1`なら「コンフリクトあり」、`0`なら「コンフリクトなし」。`--write-tree`モードは実際のマージと同じmerge-ortエンジンで判定するため、コンテンツ競合だけでなくrename・modify/delete・バイナリ・ファイルモード変更のコンフリクトも検知できる（Git 2.38以上が必要。コマンド自体が失敗して判定できない場合は「コンフリクトあり」側に倒してステップ3に進む）

**禁止**: 旧形式の`git merge-tree <base-tree> <branch1> <branch2>`（trivial mergeモード）の出力にコンフリクトマーカー（`<<<<<<<`等）が含まれるかで判定してはならない。旧形式はrename検知を行わず、modify/delete・バイナリ・モード変更などのコンフリクトではマーカーを出力しないため、GitHubが`CONFLICTING`と判定しているPRを「コンフリクトなし」と誤判定し、`triage-pr`との間で無限ループを引き起こす。

### コンフリクトなしの場合

「コンフリクトなし」を呼び出し元に返却して終了する。`git rebase`も`push`も行わない（不要なrebase/force-pushはCIを無駄に再走させ、他者がそのブランチを見ているときの混乱の元になるため）。

### コンフリクトありの場合

ステップ3に進む。

## ステップ3: rebaseによるコンフリクト解消

ターゲットブランチに対してrebaseを実行する。

```bash
git rebase "origin/$TARGET_BRANCH"
```

rebaseがコンフリクトなしで完走した場合も、そのままステップ4のpushに進む（GitHubの`CONFLICTING`判定はマージ試行に基づくため、rebase自体はクリーンに完走することがある。ここでpushせず終了するとリモートが変わらず、`triage-pr`が再度コンフリクトを検知してループする）。

rebase中にコンフリクトが発生した場合は、`git status`でコンフリクト中のファイルを特定し、それぞれを **両者の変更意図を尊重する形** で解消する。片方の変更を機械的に捨てると、PR側のレビュー意図かターゲットブランチ側の最新仕様のどちらかを取りこぼすため、必要に応じて以下を行ってから解消する。

- `Read`で該当ファイル全体を読み、コンフリクトしている関数/ブロックの責務を理解する
- `git log -p`でターゲットブランチ側・PR側それぞれの該当変更commitを確認し、変更意図を読み取る
- 周辺コードや関連テストを`Read` / `Grep`で参照し、整合性のとれた解消にする

判断できない場合（情報が足りない、両方が同じ箇所を大きく書き換えている、人間の仕様判断が必要、など）は無理に解消せず、`git rebase --abort`で取り消したうえで中断理由を呼び出し元に返却する（生半可な解消はレビュー差し戻しや本番バグ混入につながるため）。

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

`--force-with-lease`を使うのは、自分の認識していないリモートの新規commitを上書きしない（他人のpushを巻き戻さない）ため。pushが失敗した場合は、エラー内容をそのまま呼び出し元に返却して中断する。自動再試行はしない（再試行が必要なケースはリモートに新規pushが来ているなど人間判断が必要な状況のため）。

## 出力

呼び出し元には以下を構造化して返却する。

- **判定**: `no-conflict` / `resolved-and-pushed` / `aborted` のいずれか
- **詳細**:
  - `no-conflict`: ターゲットブランチ名と判定根拠（`mergeable`の値、またはフォールバック時は`git merge-tree --write-tree`の結果）
  - `resolved-and-pushed`: 解消したファイル一覧と各ファイルの解消方針の要点
  - `aborted`: 中断理由（PRがOPENでない / checkout失敗 / コンフリクト解消困難 / push失敗 など）と、その時点のgitの状態（`git status`の要約）

## 注意事項

- このスキルは **コンフリクト解消のみ** を目的とする。スコープ外の修正（Lint対応、テスト追加、リファクタリング、レビュー指摘対応）は行わない
- ステップ3のrebase中の`Edit` / `Write`以外でコードを変更しない。コンフリクトと無関係な「ついで修正」を入れると、後続のレビューと履歴が複雑になる
- **作業ディレクトリを動かさない**: ステップ0の判定に従い、worktree内で起動されたら外に出ず、worktree外で起動されたら勝手にworktreeへ移動しない。新規worktreeも作らない
- **デフォルトブランチで作業しない**: `gh pr checkout` 後にHEADがデフォルトブランチと一致する場合は中断する
- PRに付与されているラベル（`cc-triage-scope`等を含む）は一切操作しない。ラベル管理は上位スキルの責務
- `git push --force`は使わず、必ず`--force-with-lease`を使う
- コンフリクトなしの場合は何もせず終了する。不要なrebase / force-pushを発生させない
