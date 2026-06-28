---
name: create-issue
description: Create an implementation plan and a GitHub Issue based on the task description provided as an argument. Use this when the user supplies a natural-language task description (not an issue number) and wants a new implementation-ready Issue. If the input is an existing issue number, use create-issue-from-issue-number (re-analyze) or update-issue (reflect comments) instead.
argument-hint: "[task-description]"
---

# Create Issue

引数で受け取ったタスク説明をもとに要件を整理し、GitHub Issueを新規作成するためのスキルです。
Instructionsの順に最後まで自律的に実行してください。

**自律実行原則**: このスキルはユーザーへの確認を行わず、判断はすべて本スキル内のルールに従って自動で決定する。途中で質問せず、確認したいことがあれば最後にIssueへのコメントとして残す。中断条件に該当した場合のみ、理由を出力して終了する。

**入力範囲**: このスキルは「自然言語のタスク説明」のみを引数として受け付ける。引数が Issue 番号（数値のみ・`#`付き数値・Issue URL）に該当する場合は、本スキルは扱わず、コード分析をやり直して既存 Issue をリフレッシュしたい場合は `/create-issue-from-issue-number`、コメント由来の未反映事項を反映したい場合は `/update-issue` を使うようユーザーに案内して終了する。

**責務の分担**: 本スキルは「分析（タスク内容理解・コード分析）」までを担い、「本文整形・投稿前チェック・`gh issue create` 実行」は `post-issue-body` スキルへ委譲する。本文テンプレート・変更ログ追記ルール・投稿前チェックリスト・heredoc 投稿コマンドはすべて `post-issue-body` 側に集約されているため、本スキル内では再記述しない（重複を避けるため）。

# Instructions

## フェーズ0: 事前チェック

### 0-1. 引数の妥当性確認

`$ARGUMENTS` が以下に該当する場合は中断する（このスキルは新規作成専用）。判定は機械的に行い、ユーザーへの確認は不要。

- 数値のみ（例: `123`）
- `#`付き数値（例: `#123`）
- GitHubのIssue URL（`.../issues/<番号>`）

該当時は、「このスキルは新規作成専用です。既存Issueを起点に再分析するには `/create-issue-from-issue-number <番号>` を、コメントから未反映事項を反映するには `/update-issue <番号>` を使ってください」と出力して終了する。

引数が空、または意味のあるタスク説明を含まない場合も中断する。

### 0-2. 作業ディレクトリの確認

`pwd` を実行し、結果に応じて以下を判定する。worktreeを**新たに作成しない**こと。

- `.claude/worktrees/` 配下にいる → そのworktree内で作業
- それ以外（リポジトリのルート等）→ その場で作業

### 0-3. デフォルトブランチの安全な同期（fail-safeにスキップ可）

以下を順に試行し、失敗しても**中断せずスキップして続行**する。本スキルはコード変更を伴わないため、最新化に失敗しても作業継続できる。

```bash
git fetch --prune || true
```

`git rebase` や `git pull` は実行しない（未コミット変更や conflict による中断を避けるため）。

**完了条件**: 引数がタスク説明として有効と確認でき、作業ディレクトリが特定されていること。

---

## 1. タスクの分析（参考情報の収集）

タスクの背景を理解するために、**存在するもののみ**を読み込む。存在しないパスは黙ってスキップする。

- `docs/` 配下のドキュメントファイル: `ls docs/ 2>/dev/null` で存在確認した上で、タスクに関係しそうなファイルを読む
- `design/` 配下の Pencil ファイル（`.pen`）: `ls design/ 2>/dev/null` で存在確認した上で、`inspect-pencil-node` スキルで対象Nodeの属性データとスクリーンショットを取得して内容を確認する（`.pen` は暗号化バイナリのため `Read`/`Grep` は使わない）。本スキルはコードを変更しないため、`.pen` の編集が必要と判明した場合は本スキル内では編集せず、`post-issue-body` へ渡す「実装プラン」「確認事項」に「`pencil-design-updater` エージェントで `<対象 .pen>` を更新する」旨を明記して後続タスクへ委譲する（`.pen` 編集は `pencil-design-updater` 専任で、`edit-pencil-design` スキル経由での運用ルール集約を逸脱しない）

### タスク内容

$ARGUMENTS

## 2. コードの分析（Explore サブエージェントを使用）

Explore サブエージェントを起動し、以下を取得する。

- 影響範囲となる主要ファイル・ディレクトリ（最大10件）
- 既存の類似実装の参照先（最大5件、ファイルパスと役割の1行説明）
- タスク達成に必要な変更の概略（フェーズ分け可能なら3段階以内）
- 不確実性・確認事項のリスト（推測で埋めず、Issueに残す前提）

サブエージェントへのプロンプトには「ユーザーには質問せず、調査結果を返却して終了する」ことと、上記の出力フォーマットを明示する。

### 直近関連変更の確認（必須）

進行中・直近完了済みの関連作業を見落とし、既存実装と重複するゴーストタスクを含んだ冗長な Issue を起票しないため、Explore が特定した対象ファイル一覧について直近の commit 履歴と関連 PR を必ず確認する。

- 対象ファイルごとに `git log --oneline -10 <file>` を実行し、直近 commit のサマリを把握する
- `gh pr list --search "<file>"` で未マージの関連 PR を確認する
- 直近 commit に大規模リファクタ・共通ヘルパー追加などの大きな変更が含まれる場合や、未マージの関連 PR がある場合は、その内容を `post-issue-body` に渡す「直近関連変更」セクション（必要に応じて「参照情報」にも）に必ず記載し、実装プランが既存実装と重複していないか検証する
- git 履歴のない新規機能要求など確認が困難なケースでは「該当なし」と記載してスキップしてよい

**完了条件**: 上記4項目が揃い、対象ファイルの直近関連変更が把握できていること。揃わない場合でも追加調査せず、不足分は「不明」として次に進む。

## 3. post-issue-body スキルで Issue を作成

ステップ1・2の分析結果を **以下の YAML ブロックの形でそのまま args として** Skill tool で `post-issue-body` を起動する。`post-issue-body` は args（`$ARGUMENTS`）を YAML として機械的にパースして入力として扱う規約になっている。

```yaml
mode: create
title: <タスクの目的が分かる簡潔なタイトル>
sections:
  概要: |
    （1-3行）
  要件: |
    - ...
    （無ければ "なし"）
  参照情報: |
    - ドキュメント: `<path>` — <説明>
    （ステップ1で読んだ参照、無ければ "なし"）
  直近関連変更: |
    - `<commit hash>` <subject> — <影響>
    （ステップ2で確認した結果、無ければ "該当なし"）
  実装プラン: |
    1. フェーズ1
    2. フェーズ2
  影響範囲: |
    - `<path>` — <概略>
new_changelog_entry: 初版作成 — <タスクの概要を一言>
labels:
  - cc-triage-scope
  - cc-issue-created
confirmation_items:  # 0件ならキーごと省略
  - <ステップ2で抽出した未確認事項1>
  - <ステップ2で抽出した未確認事項2>
```

`labels` には `cc-triage-scope` と `cc-issue-created` の2つを必ず入れる（このスキルで作成する Issue は「Explore 分析済み（`cc-issue-created`）」かつ「人間の triage 待ち（`cc-triage-scope`）」の両方の性質を持つ前提のため、後続スキルが両方のラベルで拾えるようにする）。assignee は `post-issue-body` が `gh api user --jq '.login'` で取得した gh ログインユーザーを自動で紐づけるため、本スキルから明示的に渡す必要はない。

Skill tool 呼び出しは `Skill(skill='post-issue-body', args=<上記YAML文字列>)`（必要なら plugin namespace 付きで `base-tools:post-issue-body`）。args は改行を含む複数行文字列としてそのまま渡す。本文整形・投稿前チェック・`gh issue create`（`--label cc-triage-scope --label cc-issue-created --assignee <gh ログインユーザー>` 付き）の実行、確認事項があればコメント投稿までを `post-issue-body` が担う。完了後、Issue URL と確認事項コメントの有無が返ってくる。

`post-issue-body` の失敗（gh コマンド失敗・本文チェック不通過の解消不能等）はそのまま本スキルの中断条件となる。エラーメッセージを最終報告に含めて中断する。

## 4. 最終報告

`post-issue-body` から返ってきた Issue URL と、確認事項コメントの有無を1-3行で報告して終了する。

---

## 中断条件

以下のいずれかに該当する場合のみ、理由を出力して**即中断**する。それ以外は自律的に判断して続行する。

- 引数が空、または意味のあるタスク説明を含まない
- 引数がIssue番号（数値のみ・`#`付き数値・Issue URL）→ `/create-issue-from-issue-number` または `/update-issue` を案内して終了
- `post-issue-body` が失敗し、再試行しても解消しない

## 注意事項

- このスキルは**コードを一切変更しない**。Issue の作成・コメントは `post-issue-body` 経由で行い、本スキル内で直接 `gh issue create` を呼ばない
- 作成する Issue には常に `cc-triage-scope` と `cc-issue-created` の2ラベルを付与する（Explore 分析済みでありつつ triage フローにも乗せる前提）。`post-issue-body` への YAML から `labels` キーを落とさず、2件とも入っていることを毎回確認すること
- assignee は `post-issue-body` 側で `gh api user --jq '.login'` の結果を自動的に `--assignee` に渡す挙動になっており、本スキルから別途指定する必要はない
- 途中でユーザーに質問しない。確認したいことは `post-issue-body` へ「確認事項」として渡し、コメントとして残す
- Pencil ファイル（`.pen`）の読み込みは `inspect-pencil-node` スキル経由でのみ行う（`.pen` は暗号化バイナリのため `Read`/`Grep` は使えない）
- `.pen` の編集は本スキルでは**絶対に行わない**。必要と判明した場合は `pencil-design-updater` エージェントで対応する旨を `post-issue-body` 経由で「実装プラン」または「確認事項」に明記して後続タスクへ委譲する（手で `pencil` コマンドを直接組み立てたり、frontend-implementer/general-purpose-assistant 等で代用したりしない）
- 本文テンプレート・変更ログ追記ルール・投稿前チェック・heredoc 例は `post-issue-body` に集約されているため、本スキルでは再記述しない
