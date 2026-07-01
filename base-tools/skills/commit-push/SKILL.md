---
name: commit-push
description: コード変更を適切なgitコミット戦略でgit commitし、pushします。基本的には既存のgitコミットへのsquash戦略を採用し、必要に応じてブランチ全体のgitコミット履歴を再構成します。実装完了時やユーザーがgit commitを依頼した時に使用します。
model: haiku
context: fork
---

# Commit and Push Code Changes

**このスキルが呼び出された時点で、コード変更の git commit と push を実行する依頼は既に確定しています。ユーザーへの挨拶・自己紹介・「何を手伝いますか」「お手伝いできることはありますか」のような確認質問は一切禁止です。Instructions のステップ1（`git status` と `git log` の確認）から即座に実行を開始してください。**

ユーザーから追加の指示や引数は渡されません。デフォルトブランチからの差分・現在の作業ツリーの状態を自分で確認し、Instructions に従って戦略を選択・実行します。

このスキルは、コード変更を適切な git コミット戦略で commit し push するためのものです。基本的には既存の git コミットへの squash 戦略を採用し、必要に応じてブランチ全体の git コミット履歴を再構成します。

> **呼び出し側への必須ルール**: 本スキルは `context: fork` のサブエージェントとして起動する場合でも、**絶対にバックグラウンド実行しないこと**。`Skill` / `Agent` ツール呼び出し時に `run_in_background: true` を指定してはならない。呼び出し元は本スキルが同期的に「commit → push」まで完了したことを確認してから次工程（PR作成・レビュー依頼など）に進める設計であり、バックグラウンド化すると push 完了前に制御が戻ってしまい、後続処理がリモート未反映の状態を前提に走って破綻する。他スキル（`create-pr` / `exec-issue` / `fix-review-point` 等）や上位エージェントから呼ぶ際もこの制約を守ること。

# Instructions

## 実行モードの制約

本スキルは `context: fork` によりサブエージェントとして起動されるが、**内部で呼び出す Bash・Skill・Agent は絶対にバックグラウンド実行しないこと**。具体的には次を守る。

- Bashツール呼び出し時に `run_in_background: true` を指定しない。既定の同期実行（フォアグラウンド）でstdoutを受け取ってから次の処理に進む
- シェルコマンド末尾に `&` を付けてバックグラウンド化しない。`nohup` / `disown` / `setsid` 等でのデタッチも禁止
- `git push` など時間のかかる処理も同期実行で完了を待つ。push完了前に次のステップに進まないこと
- `Agent` / `Skill` ツールにも `run_in_background: true` を渡さない
- ScheduleWakeup 等で処理を後回しにすることも行わない。呼び出し元は本スキルの完了を同期的に待っている

**理由**: `commit` と `push` はリモート状態を確定させる副作用のあるステップであり、完了前に制御が戻ると呼び出し元は「未反映のリモートを前提とした後続処理」を走らせてしまい、CI通知の取り逃し・Force push競合・PR本文の差分ずれなどが発生する。同期完了を保証することが本スキルの契約。

## 実行ステップ

以下のステップでコード変更のgit commitとpushを行ってください。

### ステップ1: ブランチとgitコミット履歴の確認

以下のコマンドで現在の状態を確認：

```bash
git status
git log --oneline --graph "origin/$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)..HEAD"
```

確認事項：
- 現在のブランチ名
- デフォルトブランチから何gitコミット進んでいるか
- 各gitコミットの内容と粒度

### ステップ2: gitコミット戦略の判断

以下の基準でgitコミット戦略を選択：

#### 戦略A: Squash（基本戦略）

以下の条件を満たす場合、既存のgitコミットにsquashします：

- ブランチに既にgitコミットが存在する
- 変更内容が既存のgitコミットと同じテーマ・機能に関連している
- gitコミットを分ける合理的な理由がない

**実行方法：**

```bash
git add -A
git commit --amend
```

gitコミットメッセージを適切に更新してください。

#### 戦略B: 新規gitコミット

以下の場合は新規gitコミットを作成：

- ブランチに初めてのgitコミット
- 既存のgitコミットとは異なる独立した変更
- gitコミットを分けることで履歴がより理解しやすくなる

**実行方法：**

```bash
git add -A
git commit
```

#### 戦略C: Interactive Rebase（gitコミット再構成）

以下の場合はブランチ全体のgitコミットを再構成：

- 複数の小さなgitコミットを論理的なまとまりに整理したい
- gitコミットの順序を変更したい
- 不要なgitコミットを削除したい
- gitコミット履歴を意味のある単位に再編成したい

**実行方法：**

```bash
git rebase -i "origin/$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)"
```

エディタで以下の操作を実行：
- `pick`: gitコミットをそのまま維持
- `squash`または`s`: 前のgitコミットと統合
- `reword`または`r`: gitコミットメッセージを変更
- 行の順序を変更してgitコミット順を変更

### ステップ3: gitコミットメッセージのガイドライン

gitコミットメッセージは以下の形式で記述：

```
<type>: <subject>

<body>

<footer>
```

**Type:**
- `feat`: 新機能
- `fix`: バグ修正
- `refactor`: リファクタリング
- `test`: テスト追加・修正
- `docs`: ドキュメント変更
- `chore`: ビルドプロセスやツールの変更

**Subject:**
- 50文字以内
- 命令形で記述（例: "add"ではなく"Add"）
- 末尾にピリオドを付けない

**Body（オプション）:**
- 変更の理由と背景を説明
- 何を変更したかではなく、なぜ変更したかを記述
- 72文字で折り返す

**Footer（オプション）:**
- Issue番号への参照（例: `Closes #123`）
- Breaking changesの記述

### ステップ4: git commit後の確認

git commit後、以下を確認：

```bash
git log -1 --stat
git status
```

- gitコミットが正しく作成されたか
- 意図したファイルがすべて含まれているか
- gitコミットメッセージが適切か


### ステップ5: 変更のpush

変更をリモートブランチにpush：

```bash
git push origin HEAD --force-with-lease
```

## 重要な注意事項

1. **コメントは残さない**: コード内の説明コメントは削除してください
2. **原子的なgitコミット**: 各gitコミットは独立して意味を持つようにしてください
3. **一貫性**: プロジェクトの既存のgitコミットスタイルに従ってください

## 戦略選択のフローチャート

```
ブランチにgitコミットがある？
  ├─ No → 新規gitコミット作成
  └─ Yes → 変更は既存のgitコミットと同じテーマ？
      ├─ Yes → Squash（git commit --amend）
      └─ No → gitコミットを分ける合理性がある？
          ├─ Yes → 新規gitコミット作成
          └─ 履歴を整理したい → Interactive Rebase
```
