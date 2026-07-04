---
name: commit-push
description: コード変更を適切なgitコミット戦略でgit commitし、pushします。基本的には既存のgitコミットへのsquash戦略を採用し、必要に応じてブランチ全体のgitコミット履歴を再構成します。実装完了時やユーザーがgit commitを依頼した時に使用します。
model: sonnet
effort: high
context: fork
---

# Commit and Push Code Changes

**このスキルが呼び出された時点で commit と push の実行依頼は既に確定しています。ユーザーへの挨拶・自己紹介・「何を手伝いますか」のような確認質問は一切禁止。ステップ1（`git status` と `git log` の確認）から即座に実行を開始してください。**

ユーザーから追加の指示や引数は渡されません。デフォルトブランチからの差分・作業ツリーの状態を自分で確認し、Instructions に従って戦略を選択・実行します。基本は既存gitコミットへのsquash戦略を採用し、必要に応じてブランチ全体のgitコミット履歴を再構成します。

> **呼び出し側への必須ルール**: 本スキルは `context: fork` のサブエージェントとして起動する場合でも、**絶対にバックグラウンド実行しないこと**。`Agent` ツール経由で呼び出す場合は **既定が `run_in_background: true`（バックグラウンド）** のため、**必ず `run_in_background: false` を明示指定** すること。`Skill` ツール経由の場合も `run_in_background: true` を指定してはならない（既定は同期）。呼び出し元は本スキルが同期的に「commit → push」まで完了したことを確認してから次工程（PR作成・レビュー依頼など）に進む設計であり、バックグラウンド化するとpush完了前に制御が戻り、後続処理がリモート未反映を前提に走って破綻する。他スキル（`create-pr` / `exec-issue` / `fix-review-point` 等）や上位エージェントから呼ぶ際もこの制約を守ること。

# Instructions

## 実行モードの制約

内部で呼び出す Bash・Skill・Agent は絶対にバックグラウンド実行しないこと：

- **`Agent` ツールは既定が `run_in_background: true`（バックグラウンド）**。呼び出しごとに **必ず `run_in_background: false` を明示指定** し、フォアグラウンドで同期的に結果を受け取ってから次の処理に進む。指定を省略した場合はバックグラウンドで走り、本スキルが未完のまま終了する
- `Bash` / `Skill` ツールに `run_in_background: true` を指定しない（既定は同期）。既定の同期実行で結果を受け取ってから次の処理に進む
- シェルコマンド末尾に `&` を付けない。`nohup` / `disown` / `setsid` 等でのデタッチも禁止
- `git push` など時間のかかる処理も同期実行で完了を待つ。push完了前に次のステップに進まない
- ScheduleWakeup 等で処理を後回しにしない。呼び出し元は本スキルの完了を同期的に待っている

**理由**: commit / push はリモート状態を確定させる副作用ステップであり、完了前に制御が戻ると呼び出し元が未反映のリモートを前提に後続処理を走らせ、CI通知の取り逃し・force push競合・PR本文の差分ずれが発生する。同期完了の保証が本スキルの契約。

## 実行ステップ

### ステップ0: 作業ディレクトリの確認

本スキルは単独でも他スキル（`exec-issue` / `fix-review-point` / `create-pr` 等）からの委譲でも起動される。いずれのケースでも、呼び出し元が用意した作業コンテキストを尊重するため、**現在地を変更しない・新規worktreeを作らない**ことを徹底する。

```bash
pwd
```

判定:

- **`.claude/worktrees/` 配下にいる場合**: そのworktree内で全ての作業（`git status` / `git commit` / `git push` 等）を完結させる。`cd`でworktreeの外やリポジトリのルートに移動しない。新規worktreeも作らない
- **`.claude/worktrees/` 配下にいない場合（リポジトリのルート・通常のクローン等）**: その場で作業する。`.claude/worktrees/` 配下への移動や新規worktree作成はしない

**理由**: 本スキルは `context: fork` のサブエージェントとして起動される場合、親エージェントと同じ作業ディレクトリで実行される。親がworktree内で作業していたなら、そのworktreeでcommit/pushを完結させる必要がある。作業ディレクトリを勝手に動かすと、親の期待する変更対象と実際にcommitされる変更対象がずれ、リモートに誤った差分がpushされる。

本スキルはデフォルトブランチ上でも実行でき、その場合はデフォルトブランチへ直接commit / pushする。ただし公開済みのデフォルトブランチ履歴を壊さないよう、デフォルトブランチ上では**新規コミットの追加とforce無しのfast-forward pushに限定**する（既pushコミットの `--amend` / interactive rebase / force push はしない）。ステップ1で現在ブランチがデフォルトブランチかどうかを判定し、以降のコミット戦略とpush方法を切り替える。

### ステップ1: ブランチとgitコミット履歴の確認

```bash
git status
DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
git log --oneline --graph "origin/${DEFAULT_BRANCH}..HEAD"
```

確認事項: 現在のブランチ名／デフォルトブランチから何gitコミット進んでいるか／各gitコミットの内容と粒度

取得した `CURRENT_BRANCH` と `DEFAULT_BRANCH` から、以降のモードを決める:

- **デフォルトブランチモード**（`CURRENT_BRANCH` と `DEFAULT_BRANCH` が一致する場合、**または `DEFAULT_BRANCH` の取得に失敗した場合**）: デフォルトブランチ上での作業とみなす。公開済み履歴を壊さないため、ステップ2では**戦略B（新規gitコミット）のみ**を採用し（`--amend`＝戦略A・interactive rebase＝戦略Cは使わない）、ステップ5では**force無しのfast-forward push**（`git push origin HEAD`）を使う。取得失敗時もこのモードへ倒すのは、判定できない状態で force push してデフォルトブランチ履歴を壊す事故を避けるため（fail-safe。取得失敗時は `git log` の差分確認はスキップしてよい）。
- **通常モード**（両者が一致せず、かつ `DEFAULT_BRANCH` も取得できている場合）: feature branch上での作業とみなす。ステップ2の戦略A/B/Cすべてを選べ、ステップ5は `--force-with-lease` 付きpushを使う。

### ステップ2: gitコミット戦略の判断

> **デフォルトブランチモードでは戦略Bのみを使う**。デフォルトブランチの履歴は既にリモートへ公開されており、`--amend`（戦略A）や interactive rebase（戦略C）で書き換えると他のクローン・CI・オープン中のPRと齟齬が出るため。デフォルトブランチ上の変更は常に新規コミットとして積む。以下の戦略A/Cは通常モード（feature branch）でのみ選択できる。

#### 戦略A: Squash（基本戦略）

以下を満たす場合、既存のgitコミットにsquashする: ブランチに既にgitコミットが存在し、変更内容が既存のgitコミットと同じテーマ・機能に関連し、gitコミットを分ける合理的な理由がない。

```bash
git add -A
git commit --amend
```

gitコミットメッセージを適切に更新すること。

#### 戦略B: 新規gitコミット

以下の場合は新規gitコミットを作成: ブランチに初めてのgitコミット／既存のgitコミットとは異なる独立した変更／gitコミットを分けることで履歴がより理解しやすくなる。

```bash
git add -A
git commit
```

#### 戦略C: Interactive Rebase（gitコミット再構成）

以下の場合はブランチ全体を再構成: 複数の小さなgitコミットの論理的な整理／順序変更／不要なgitコミットの削除／意味のある単位への再編成。

```bash
git rebase -i "origin/$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)"
```

エディタでの操作: `pick`=そのまま維持／`squash`（`s`）=前のgitコミットと統合／`reword`（`r`）=メッセージ変更／行の順序変更=gitコミット順の変更

### ステップ3: gitコミットメッセージのガイドライン

```
<type>: <subject>

<body>

<footer>
```

- **Type**: `feat`（新機能）/ `fix`（バグ修正）/ `refactor`（リファクタリング）/ `test`（テスト追加・修正）/ `docs`（ドキュメント変更）/ `chore`（ビルドプロセスやツールの変更）
- **Subject**: 50文字以内、命令形で記述（例: "add"ではなく"Add"）、末尾にピリオドを付けない
- **Body（オプション）**: 何を変更したかではなく、なぜ変更したか（理由と背景）を記述。72文字で折り返す
- **Footer（オプション）**: Issue番号への参照（例: `Closes #123`）、Breaking changesの記述

### ステップ4: git commit後の確認

```bash
git log -1 --stat
git status
```

gitコミットが正しく作成されたか／意図したファイルがすべて含まれているか／メッセージが適切か

### ステップ5: 変更のpush

ステップ1で判定したモードに応じてpush方法を分ける。

- **通常モード（feature branch）**: rebaseやamendで履歴が変わり得るため `--force-with-lease` を使う。

```bash
git push origin HEAD --force-with-lease
```

- **デフォルトブランチモード**: 新規コミットを積んだだけのfast-forwardなので、force系フラグは**付けずに**通常pushする。デフォルトブランチへ `--force` / `--force-with-lease` を使うと公開履歴を巻き戻す事故につながるため絶対に付けない。

```bash
git push origin HEAD
```

デフォルトブランチモードのpushがnon-fast-forwardで弾かれた場合は、リモートに未取得のコミットがある状態。force pushで押し込まず、`git fetch` してから `git log origin/${DEFAULT_BRANCH}..HEAD` と `git log HEAD..origin/${DEFAULT_BRANCH}` で差分を確認し、追従（`git pull --ff-only` など）してから再pushする。

## 重要な注意事項

1. **コメントは残さない**: コード内の説明コメントは削除する
2. **原子的なgitコミット**: 各gitコミットは独立して意味を持たせる
3. **一貫性**: プロジェクトの既存のgitコミットスタイルに従う
4. **作業ディレクトリを動かさない**: ステップ0の判定に従い、worktree内で起動されたら外に出ず、worktree外で起動されたら勝手にworktreeへ移動しない。新規worktreeも作らない
5. **デフォルトブランチ上では履歴を書き換えない**: デフォルトブランチ上でもcommit / pushできる。ただし公開済み履歴を壊さないため、新規コミットの追加とforce無しのfast-forward pushに限定し、`--amend`（戦略A）・interactive rebase（戦略C）・force pushはしない（ステップ1のモード判定に従う）

## 戦略選択のフローチャート

```
デフォルトブランチにいる？（DEFAULT_BRANCH 取得失敗も Yes 扱い）
  ├─ Yes（デフォルトブランチモード）→ 新規gitコミットのみ作成 → force無しでpush（fast-forward）
  └─ No（feature branch / 通常モード）→ ↓
ブランチにgitコミットがある？
  ├─ No → 新規gitコミット作成 → --force-with-lease でpush
  └─ Yes → 変更は既存のgitコミットと同じテーマ？
      ├─ Yes → Squash（git commit --amend）→ --force-with-lease でpush
      └─ No → gitコミットを分ける合理性がある？
          ├─ Yes → 新規gitコミット作成 → --force-with-lease でpush
          └─ 履歴を整理したい → Interactive Rebase → --force-with-lease でpush
```
