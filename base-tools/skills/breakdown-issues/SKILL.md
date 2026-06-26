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

### 4. 親（Epic）Issue の作成

子Issueを作る前に、ステップ2で分解した全TODOを束ねる「親Issue（Epic）」を1つ作成する。子Issueは後段でこの親Issueの sub-issue として作成するので、先に親番号を確定させておく必要がある。

親Issueは GitHub UI 上で「この一連のタスク群が何を達成するためのものか」をひと目で示すサマリとして機能する。子Issueの全体像と進捗を1つの番号で追えるようにすることが目的。

- **ラベル**: `cc-epic-issue`（親 Epic Issue であることを示す。必ず付与）
- **タイトル**: ステップ2で取りまとめた「依頼内容全体」のサマリを短くまとめたもの（例：「ユーザー認証機能の実装」「決済フローのリファクタ」）
- **アサイン**: 自分（`$ME`）
- **本文**: 依頼内容の全体像（背景・ゴール）を1-3段落で簡潔に。子Issueは本ステップ完了後に作るため、この時点では子Issue番号のリンクは含めない（必要なら最終ステップで `gh issue edit` で追記してもよいが、GitHub UI の sub-issue 表示で十分追えるので必須ではない）

`post-scope-issue-body` のフォーマットは個別TODO用のスコープIssue向け（要件・参照情報・優先度・見積もり規模）であり、Epicサマリには合わない。親Issueはこのスキル内で直接 `gh issue create` する。

```bash
ME=$(gh api user --jq '.login')

EPIC_ISSUE_URL=$(gh issue create \
  --title "<Epicタイトル>" \
  --assignee "$ME" \
  --label "cc-epic-issue" \
  --body-file - <<'EOF'
## 概要
（依頼内容の全体像を1-3段落で）

## 背景・ゴール
（このEpicが達成すべきゴール、なぜ必要か）
EOF
)

EPIC_ISSUE_NUMBER=$(basename "$EPIC_ISSUE_URL")
```

`gh issue create` が失敗した場合は本ステップでそのまま中断する（親Issueが無い状態で子Issueだけ作っても sub-issue 関係が貼れず、本スキルの趣旨を満たさないため）。

### 5. 子IssueをサブIssueとして一括作成（post-scope-issue-body へ委譲）

ステップ2で洗い出した各TODOに対して、ステップ4で作った親Issueの sub-issue として GitHub Issue を作成する。

#### 責務の分担

本文整形・投稿前チェック・`gh issue create` の実行は `post-scope-issue-body` スキルに委譲する。本文テンプレート・投稿前チェックリスト・heredoc 投稿コマンドはすべて `post-scope-issue-body` 側に集約されているため、本スキル内では再記述しない（重複を避けるため、また `post-scope-issue-body` との不整合を生まないため）。

本スキルでは「TODOの整理」「作成順序の制御」「親Issue番号と依存先Issue番号の確定と YAML への受け渡し」のみを担う。

#### 依存関係の表現方法

依存関係は本文の `## 依存関係` セクションには書かない。GitHub ネイティブの relationships（blocked-by）を使い、`post-scope-issue-body` の YAML 入力に `blocked_by:` を渡して `gh issue create --blocked-by` 経由で貼る。これにより GitHub UI 上で関係性が表示され、本文との二重管理によるズレも避けられる。

#### 作成順序

依存関係のないタスク（依存先が「なし」のもの）から先に作成し、依存先のIssue番号が確定してから依存タスクのIssueを作成する。`post-scope-issue-body` は1回呼び出しにつき1つのIssueを作成して URL と Issue 番号を返すので、本スキルはそれを順に呼び出し、後続TODOの `blocked_by:` リストに先行Issueの番号を入れてから次の呼び出しを行う。

#### 各TODOごとの呼び出し

TODO 1件ごとに、以下の YAML ブロックを**そのまま args として** Skill tool で `post-scope-issue-body` を起動する。`post-scope-issue-body` は args（`$ARGUMENTS`）を YAML として機械的にパースして入力として扱う規約になっている。

```yaml
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
  優先度: High  # High / Medium / Low のいずれか
  見積もり規模: M  # S / M / L / XL のいずれか
# ステップ4で確定した親Issue番号。全TODOで同じ値を渡す。
parent: <EPIC_ISSUE_NUMBER>
# 依存先がある場合のみ書く。先行して作成済みのIssue番号を入れる。依存先が無い場合は項目ごと省略。
blocked_by: [<先行TODOで確定済みのIssue番号>, ...]
```

Skill tool 呼び出しは `Skill(skill='post-scope-issue-body', args=<上記YAML文字列>)`（必要なら plugin namespace 付きで `base-tools:post-scope-issue-body`）。args は改行を含む複数行文字列としてそのまま渡す。`post-scope-issue-body` が完了後、作成された Issue URL と Issue 番号を返す。番号は次以降のTODOの `blocked_by:` に入れる用途で保持する。

`post-scope-issue-body` の失敗（gh コマンド失敗・本文チェック不通過・`--parent`/`--blocked-by` の検証エラー等）はそのまま本ステップの中断条件となる。エラーメッセージを最終報告に含め、既に作成済みのIssue（親Issueと作成済みの子Issue）は残したまま中断する。

### 6. 作成結果の報告

全Issueの作成が完了したら、以下を報告する：

- 作成した親Issue（Epic）の番号・タイトル・URL
- 作成した子Issueの一覧（番号・タイトル・blocked-by先）
- 依存関係図（テキストベース）
- 推奨される実行順序
