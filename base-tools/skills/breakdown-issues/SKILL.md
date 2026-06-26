---
name: breakdown-issues
description: "依頼された内容を要件とTODOに分解し、タスクごとにGitHub Issueを作成するスキル。タスクの整理・分解、複数Issueの一括作成、依存関係の明示が必要な場合に使用する。「この機能をIssueに分けて」「タスクを洗い出してIssueにして」「要件を整理してチケット化して」といったリクエストで発動する。"
argument-hint: "[task-description]"
model: opus
effort: xhigh
---

# Breakdown Issues

依頼された内容を requirement-todo-organizer エージェントで要件・TODOに分解し、各タスクをGitHub Issueとして作成するスキルです。

# Instructions

## 実行ステップ

### 1. デフォルトブランチへの移動

デフォルトブランチに移動し、`git pull origin`で最新状態にする。

### 2. タスクの分解

requirement-todo-organizer サブエージェントを使用して、以下の依頼内容を要件定義・TODO分解する。

#### 依頼内容

$ARGUMENTS

### 3. タスクの不明点のブラッシュアップ

ステップ2で分解した要件・TODOに不明点や曖昧な点があれば、`AskUserQuestion`ツールを使用してユーザーに質問する。

- 回答を受けて要件・TODOを更新し、さらに不明点があれば再度質問する
- 不明点がなくなるまでこのプロセスを繰り返す
- 不明点がない場合はこのステップをスキップする

### 4. GitHub Issueの一括作成（post-scope-issue-body へ委譲）

ステップ2で洗い出した各TODOに対して、GitHub Issueを作成する。

#### 責務の分担

本文整形・投稿前チェック・`gh issue create` の実行は `post-scope-issue-body` スキルに委譲する。本文テンプレート・投稿前チェックリスト・heredoc 投稿コマンドはすべて `post-scope-issue-body` 側に集約されているため、本スキル内では再記述しない（重複を避けるため、また `post-scope-issue-body` との不整合を生まないため）。

本スキルでは「TODOの整理」「作成順序の制御」「依存先 Issue 番号の確定と書き込み」のみを担う。

#### 作成順序

依存関係のないタスク（依存先が「なし」のもの）から先に作成し、依存先のIssue番号が確定してから依存タスクのIssueを作成する。`post-scope-issue-body` は1回呼び出しにつき1つのIssueを作成して URL と Issue 番号を返すので、本スキルはそれを順に呼び出し、後続TODOの `## 依存関係` セクションに先行Issueの番号を書き込んでから次の呼び出しを行う。

#### 各TODOごとの呼び出し

TODO 1件ごとに、以下の YAML ブロックを**コンテキストに出力したうえで** Skill tool で `post-scope-issue-body` を起動する。`post-scope-issue-body` はこの YAML を機械的に拾って入力として扱う規約になっている。

```yaml
post-scope-issue-body-input:
  mode: create
  title: <TODOのタスク名をそのまま>
  sections:
    概要: |
      （1-3行）
    要件: |
      - ...
      （無ければ "なし"）
    参照情報: |
      - ドキュメント: `<path>` — <説明>
      （無ければ "なし"）
    依存関係: |
      - #<先行TODOで確定済みのIssue番号>
      （依存先がなければ "なし"）
    優先度: High  # High / Medium / Low のいずれか
    見積もり規模: M  # S / M / L / XL のいずれか
```

Skill tool 呼び出しは `Skill(skill='post-scope-issue-body', args='mode=create')`（必要なら plugin namespace 付きで `base-tools:post-scope-issue-body`）。`post-scope-issue-body` が完了後、作成された Issue URL と Issue 番号を返す。番号は次以降のTODOの `## 依存関係` セクションに書き込む用途で保持する。

`post-scope-issue-body` の失敗（gh コマンド失敗・本文チェック不通過の解消不能等）はそのまま本ステップの中断条件となる。エラーメッセージを最終報告に含め、既に作成済みのIssueは残したまま中断する。

### 5. 作成結果の報告

全Issueの作成が完了したら、以下を報告する：

- 作成したIssueの一覧（番号・タイトル・依存関係）
- 依存関係図（テキストベース）
- 推奨される実行順序
