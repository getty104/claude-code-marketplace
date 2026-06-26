---
name: create-issue-from-issue-number
description: Re-analyze an existing GitHub Issue using its current title and body as input, refresh the implementation plan against the latest code state, and update the Issue in place. Use this when the user provides an Issue number (numeric, `#`-prefixed, or Issue URL) and wants to regenerate the Explore-based analysis. For reflecting comment-driven updates instead, use update-issue. For creating a brand-new Issue from a natural-language task description, use create-issue.
argument-hint: "[Issue番号]"
---

# Create Issue From Issue Number

引数で受け取ったIssue番号をもとに、対象Issueの既存の title/body を入力として再度コード分析を行い、description をリフレッシュするためのスキルです。
Instructionsの順に最後まで自律的に実行してください。

**自律実行原則**: このスキルはユーザーへの確認を行わず、判断はすべて本スキル内のルールに従って自動で決定する。途中で質問せず、確認したいことがあれば最後にIssueへのコメントとして残す。中断条件に該当した場合のみ、理由を出力して終了する。

**入力範囲**: このスキルは「Issue番号」のみを引数として受け付ける（数値のみ・`#`付き数値・Issue URL）。引数がそれ以外（自然言語のタスク説明など）の場合は `/create-issue` を案内して終了する。

**update-issue との違い**: `update-issue` は対象Issueの**コメント全件**を入力として未反映事項を反映する。本スキルは**既存の title/body そのもの**を入力として Explore でコード分析をやり直し、実装プラン・影響範囲・直近関連変更などを最新のコード状態に合わせて refresh する。コメントを取り込みたい場合は `/update-issue` を使う。

**責務の分担**: 本スキルは「既存Issue取得・タスク内容理解・コード再分析」までを担い、「本文整形・投稿前チェック・既存変更ログの verbatim 再掲・`gh issue edit` 実行」は `post-issue-body` スキルへ委譲する。本文テンプレート・変更ログ追記ルール・投稿前チェックリスト・heredoc 投稿コマンドはすべて `post-issue-body` 側に集約されているため、本スキル内では再記述しない。

# Instructions

## フェーズ0: 引数判定と事前チェック

### 0-1. 引数の妥当性確認

`$0` を以下のいずれかに該当することを確認し、Issue番号を抽出する。判定は機械的に行い、ユーザーへの確認は不要。

- 数値のみ（例: `123`）
- `#`付き数値（例: `#123`）
- GitHubのIssue URL（`.../issues/<番号>`）

該当しない場合（自然言語のタスク説明など）は、「このスキルは既存Issueの再分析専用です。新規Issueを作成するには `/create-issue <タスク内容>` を使ってください」と出力して終了する。

引数が空の場合も中断する。

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

**完了条件**: Issue番号が確定し、作業ディレクトリが特定されていること。

---

## 1. 既存Issueの取得

引数から抽出したIssue番号で対象Issueを取得し、現在の内容を確認する。

```bash
gh issue view $0 --json number,title,state,labels,body,url
```

`state` が `CLOSED` の場合は更新せず、その旨を報告して終了する。

本文に画像URLがある場合、`gh-asset` でダウンロードして内容を読む。テキストだけでは伝わらない仕様（UIの見た目・エラー画面・図など）が分析の判断に必要なことがあるため、URLを見て終わりにせず、ダウンロードした画像を実際に Read で確認する。

```bash
gh-asset download <asset_id> ~/Downloads/
```

参考: https://github.com/YuitoSato/gh-asset

なお、変更ログを verbatim で再掲するための既存本文取得は `post-issue-body` が `mode=edit` で再度行うため、本ステップで取得した body は分析用途で使い、`post-issue-body` へは Issue 番号だけを伝えればよい。

**完了条件**: 既存の title・body・labels が取得でき、`state` が `OPEN` であること。

## 2. タスクの分析（参考情報の収集）

ステップ1で取得した既存の title/body をタスク説明として扱い、背景を理解するために、**存在するもののみ**を読み込む。存在しないパスは黙ってスキップする。

- `docs/` 配下のドキュメントファイル: `ls docs/ 2>/dev/null` で存在確認した上で、タスクに関係しそうなファイルを読む
- `design/` 配下の Pencil ファイル（`.pen`）: `ls design/ 2>/dev/null` で存在確認した上で、pencil MCP（`mcp__pencil__open_document` 等）で読む。Pencilファイルは encrypted のため Read/Grep は使わない

## 3. コードの分析（Explore サブエージェントを使用）

Explore サブエージェントを起動し、以下を取得する。スコープは「既存Issueの title/body に記述されている内容」を基準にする。

- 影響範囲となる主要ファイル・ディレクトリ（最大10件）
- 既存の類似実装の参照先（最大5件、ファイルパスと役割の1行説明）
- タスク達成に必要な変更の概略（フェーズ分け可能なら3段階以内）
- 不確実性・確認事項のリスト（推測で埋めず、Issueに残す前提）

サブエージェントへのプロンプトには「ユーザーには質問せず、調査結果を返却して終了する」ことと、上記の出力フォーマットを明示する。

### 直近関連変更の確認（必須）

進行中・直近完了済みの関連作業を見落とし、既存実装と重複するゴーストタスクを含んだ Issue に更新しないため、Explore が特定した対象ファイル一覧について直近の commit 履歴と関連 PR を必ず確認する。

- 対象ファイルごとに `git log --oneline -10 <file>` を実行し、直近 commit のサマリを把握する
- `gh pr list --search "<file>"` で未マージの関連 PR を確認する
- 直近 commit に大規模リファクタ・共通ヘルパー追加などの大きな変更が含まれる場合や、未マージの関連 PR がある場合は、その内容を `post-issue-body` に渡す「直近関連変更」セクション（必要に応じて「参照情報」にも）に必ず記載し、実装プランが既存実装と重複していないか検証する
- git 履歴のない新規機能要求など確認が困難なケースでは「該当なし」と記載してスキップしてよい

**完了条件**: 上記4項目が揃い、対象ファイルの直近関連変更が把握できていること。揃わない場合でも追加調査せず、不足分は「不明」として次に進む。

## 4. post-issue-body スキルで Issue を更新

ステップ1〜3の分析結果を **以下の YAML ブロックの形でそのまま args として** Skill tool で `post-issue-body` を起動する。`post-issue-body` は args（`$ARGUMENTS`）を YAML として機械的にパースして入力として扱う規約になっている。

```yaml
mode: edit
issue_number: <ステップ1で確定した番号>
title: <更新後タイトル — 変えない場合はステップ1で取得した既存タイトルを再掲>
sections:
  概要: |
    （1-3行、再分析結果を反映）
  要件: |
    - ...
    （無ければ "なし"）
  参照情報: |
    - ドキュメント: `<path>` — <説明>
    （ステップ2で読んだ参照、無ければ "なし"）
  直近関連変更: |
    - `<commit hash>` <subject> — <影響>
    （ステップ3で確認した結果、無ければ "該当なし"）
  実装プラン: |
    1. （再分析後の最新版）
  影響範囲: |
    - `<path>` — <概略>
new_changelog_entry: Explore再分析で実装プランと影響範囲を更新  # 再分析で変えた点を1行
confirmation_items:  # 0件ならキーごと省略
  - <ステップ3で抽出した未確認事項>
```

Skill tool 呼び出しは `Skill(skill='post-issue-body', args=<上記YAML文字列>)`（必要なら plugin namespace 付きで `base-tools:post-issue-body`）。args は改行を含む複数行文字列としてそのまま渡す。`post-issue-body` の責務範囲は以下のとおりで、本スキルから重複して実行しない。

- `gh issue view --json body` で既存本文を再取得して変更ログを verbatim で再掲
- 本文テンプレート・投稿前チェックリストに従って本文を組み立て・検証
- `gh issue edit` で更新
- 確認事項が渡されていればコメント投稿

完了後、Issue URL と確認事項コメントの有無が返ってくる。

## 5. 最終報告

`post-issue-body` から返ってきた Issue URL と、確認事項コメントの有無を1-3行で報告して終了する。

---

## 中断条件

以下のいずれかに該当する場合のみ、理由を出力して**即中断**する。それ以外は自律的に判断して続行する。

- 引数が空、または Issue 番号として解釈できない（自然言語のタスク説明など）→ `/create-issue` を案内して終了
- `gh issue view` で対象 Issue が見つからない
- `gh issue view` の結果が `CLOSED`
- `post-issue-body` が失敗し、再試行しても解消しない

## 注意事項

- このスキルは**コードを一切変更しない**。Issue の更新・コメントは `post-issue-body` 経由で行い、本スキル内で直接 `gh issue edit` を呼ばない
- 途中でユーザーに質問しない。確認したいことは `post-issue-body` へ「確認事項」として渡し、コメントとして残す
- Pencil ファイル（`.pen`）は pencil MCP 経由でのみ読む。Read/Grep は使わない
- 入力は既存の title/body のみ。コメント由来の更新は `/update-issue` の責務であり、本スキルでは取り込まない
- 本文テンプレート・変更ログ追記ルール・投稿前チェック・heredoc 例は `post-issue-body` に集約されているため、本スキルでは再記述しない
