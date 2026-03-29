---
name: breakdown-issues
description: "依頼された内容を要件とTODOに分解し、タスクごとにGitHub Issueを作成するスキル。タスクの整理・分解、複数Issueの一括作成、依存関係の明示が必要な場合に使用する。「この機能をIssueに分けて」「タスクを洗い出してIssueにして」「要件を整理してチケット化して」といったリクエストで発動する。"
argument-hint: "[task-description]"
model: opus
effort: middle
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

### 4. GitHub Issueの一括作成

ステップ2で洗い出した各TODOに対して、GitHub Issueを作成する。

#### 作成順序

依存関係のないタスク（依存先が「なし」のもの）から先に作成し、依存先のIssue番号が確定してから依存タスクのIssueを作成する。

#### Issue作成時のルール

- **Assignees**: `gh api user --jq '.login'`で取得したユーザーをアサインする
- **タイトル**: TODOのタスク名をそのまま使用する
- **本文**: 以下の構造で作成する

```
## 概要
（TODOの説明をもとに、このタスクが達成すべきゴールを記述）

## 要件
（このタスクに関連する機能要件・非機能要件をリストアップ）

## 参照情報
（このタスクに関連するドキュメントファイルのパスやデザインファイルのパス、およびそれぞれの関連箇所の説明）

## 依存関係
（依存先のIssueがある場合、`- #<Issue番号>` の形式でリンクする。なければ「なし」）

## 優先度
（High / Medium / Low）

## 見積もり規模
（S / M / L / XL）
```

#### Issue作成コマンド

```bash
gh issue create --title "タイトル" --body "本文" --assignee "<ユーザー名>" --label "cc-triage-scope"
```

### 5. 作成結果の報告

全Issueの作成が完了したら、以下を報告する：

- 作成したIssueの一覧（番号・タイトル・依存関係）
- 依存関係図（テキストベース）
- 推奨される実行順序
