---
name: update-issue
description: Update an existing GitHub Issue's description based on the issue number. Reads all issue comments and reflects any items not yet captured in the description.
argument-hint: "[Issue番号]"
hooks:
  Stop:
    - matcher: ""
      hooks:
        - type: command
          command: docker compose down --volumes --remove-orphans
---

# Update Issue

引数で受け取ったIssue番号をもとに、Issueのコメントを全件読み取って文脈を把握し、まだdescriptionに反映されていない事項を反映するためのスキルです。
このスキルが呼び出された際には、Instructionsに従って、Issueの内容とコメントを確認し、コードの分析を行い、Issueのdescriptionの更新を行ってください。

**責務の分担**: 本スキルは「既存Issueとコメント取得・未反映事項の抽出・コード分析」までを担い、「本文整形・投稿前チェック・既存変更ログの verbatim 再掲・`gh issue edit` 実行」は `post-issue-body` スキルへ委譲する。本文テンプレート・変更ログ追記ルール・投稿前チェックリスト・heredoc 投稿コマンドはすべて `post-issue-body` 側に集約されているため、本スキル内では再記述しない。

# Instructions

## 実行ステップ

### 1. 作業ディレクトリの確認とデフォルトブランチの同期

`pwd` で現在地を確認する。`.claude/worktrees/` 配下にいればそのworktree内で、それ以外（リポジトリのルート等）ではその場で作業する。worktreeを新たに作成しないこと。

デフォルトブランチの最新化は以下を試行し、失敗しても中断せずスキップして続行する。このスキルはコードを変更しないため、最新化に失敗しても作業を継続できる。

```bash
git fetch --prune || true
```

`git rebase` や `git pull` は実行しない（未コミット変更や conflict による中断を避けるため）。

### 2. 既存Issueの取得

引数から先頭のIssue番号を取り出し、そのIssueを取得して現在の内容を確認する。

```
gh issue view <Issue番号> --json number,title,state,labels,body,url
```

なお、変更ログを verbatim で再掲するための既存本文取得は `post-issue-body` が `mode=edit` で再度行うため、本ステップで取得した body は分析用途（差分検出のため）で使い、`post-issue-body` へは Issue 番号だけを伝えればよい。

#### コメントの取得（必須）

コメント全件が更新の唯一の入力になるため、必ず併せて取得する。

```
gh issue view <Issue番号> --comments
```

本文・コメントに画像URLがある場合、`gh-asset` でダウンロードして内容を読む。テキストだけでは伝わらない仕様（UIの見た目・エラー画面・図など）がdescription更新の判断に必要なことがあるため、URLを見て終わりにせず、ダウンロードした画像を実際に Read で確認する。

```
gh-asset download <asset_id> ~/Downloads/
```

参考: https://github.com/YuitoSato/gh-asset

### 3. タスクの分析

ステップ2で取得したコメント全件を入力として扱う。各コメントを時系列で読み、確認事項への回答・仕様変更・追加要望などを洗い出したうえで、既存descriptionと突き合わせ、**まだ反映されていない事項**を今回の更新対象とする。

- 既にdescriptionへ反映済みの内容は本文・変更ログともに再掲のみとし、重複した変更を加えない
- コメントが本文と矛盾する場合は、より新しいコメントの合意を優先する
- 反映すべき未反映事項が1件も無い場合は、descriptionを更新せず（ステップ5の `post-issue-body` 起動をスキップ）、その判断をユーザーに報告して終了する

加えて、タスクの内容を理解するために、要件定義ドキュメントやデザインファイル（Pencilファイル）を読み込み、タスクの背景・目的・関連する仕様を把握する。Pencilファイルはpencil MCPツールを使用して読み込むこと。

### 4. コードの分析

Explore サブエージェントで未反映事項に基づき、コードベースをできるだけ詳細に分析してください。
ユーザーへの確認が必要な事項がある場合は途中で質問をせず、実装後、Issue へ確認事項として残す（`post-issue-body` へ「確認事項」として渡せばコメントとして投稿される）。

#### 直近関連変更の確認（必須）

進行中・直近完了済みの関連作業を見落とし、既存実装と重複するゴーストタスクを含んだ Issue に更新しないため、対象ファイル一覧について直近の commit 履歴と関連 PR を必ず確認する。

- 対象ファイルごとに `git log --oneline -10 <file>` を実行し、直近 commit のサマリを把握する
- `gh pr list --search "<file>"` で未マージの関連 PR を確認する
- 直近 commit に大規模リファクタ・共通ヘルパー追加などの大きな変更が含まれる場合や、未マージの関連 PR がある場合は、その内容を `post-issue-body` に渡す「直近関連変更」セクション（必要に応じて「参照情報」にも）に必ず記載し、実装プランが既存実装と重複していないか検証する
- git 履歴のない新規機能要求など確認が困難なケースでは「該当なし」と記載してスキップしてよい

### 5. post-issue-body スキルで Issue を更新

ステップ2〜4の分析結果を **以下の YAML ブロックの形でコンテキストに出力** したうえで、Skill tool で `post-issue-body` を起動する。`post-issue-body` はこの YAML を機械的に拾って入力として扱う規約になっている。

```yaml
post-issue-body-input:
  mode: edit
  issue_number: <ステップ2で確定した番号>
  title: <更新後タイトル — 変えない場合はステップ2で取得した既存タイトルを再掲>
  sections:
    概要: |
      （1-3行、コメント由来の更新を反映）
    要件: |
      - ...
      （無ければ "なし"）
    参照情報: |
      - ドキュメント: `<path>` — <説明>
      （無ければ "なし"）
    直近関連変更: |
      - `<commit hash>` <subject> — <影響>
      （ステップ4で確認した結果、無ければ "該当なし"）
    実装プラン: |
      1. （コメント反映後の最新版）
    影響範囲: |
      - `<path>` — <概略>
  new_changelog_entry: コメントの〇〇を要件に反映  # コメントから反映した内容が分かる粒度で1行
  confirmation_items:  # 0件ならキーごと省略
    - <ステップ4で新たに発生した未確認事項>
```

Skill tool 呼び出しは `Skill(skill='post-issue-body', args='mode=edit issue_number=<番号>')`（必要なら plugin namespace 付きで `base-tools:post-issue-body`）。`post-issue-body` の責務範囲は以下のとおりで、本スキルから重複して実行しない。

- `gh issue view --json body` で既存本文を再取得して変更ログを verbatim で再掲
- 本文テンプレート・投稿前チェックリストに従って本文を組み立て・検証
- `gh issue edit` で更新（`--add-label "cc-issue-created"`、`--remove-label` は不使用）
- 確認事項が渡されていればコメント投稿

完了後、Issue URL と確認事項コメントの有無が返ってくる。未反映事項が0件と判断した場合は `post-issue-body` を起動せず、その旨をユーザーに報告して終了する。

## 中断条件

- 引数が空、または Issue 番号として解釈できない
- `gh issue view` で対象 Issue が見つからない、または `CLOSED`
- `post-issue-body` が失敗し、再試行しても解消しない

## 注意事項

- このスキルは**コードを一切変更しない**。Issue の更新・コメントは `post-issue-body` 経由で行い、本スキル内で直接 `gh issue edit` を呼ばない
- 途中でユーザーに質問しない。確認したいことは `post-issue-body` へ「確認事項」として渡し、コメントとして残す
- Pencil ファイル（`.pen`）は pencil MCP 経由でのみ読む。Read/Grep は使わない
- 本文テンプレート・変更ログ追記ルール・投稿前チェック・heredoc 例は `post-issue-body` に集約されているため、本スキルでは再記述しない
