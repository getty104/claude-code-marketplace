---
name: triage-issues
description: Triage GitHub issues assigned to the user. Categorize and process issues by adding appropriate labels (cc-create-issue, cc-exec-issue, or cc-update-issue) based on dependency analysis, issue detail status, and whether confirmation items need answers.
argument-hint: "[limit]"
model: sonnet
effort: high
---

# Triage Issues

ユーザーにアサインされたIssueを取得し、各Issueの状態に応じて適切なラベルを付与するトリアージスキルです。

# Instructions

## 実行ステップ

### 1. Issue取得と依存関係グラフの構築

以下はユーザーにアサインされたIssue一覧です。

Issue一覧: !`gh issue list --assignee "$(gh api user --jq '.login')" --label "cc-triage-scope" --search "sort:created-asc -label:cc-create-issue -label:cc-update-issue -label:cc-exec-issue -label:cc-pr-created" --json number,title,labels,body,state --limit $0`

上記のデータを使い、`issue-dependency-analyzer` サブエージェントを起動して依存関係グラフを構築し、各Issueの依存状態（resolved / blocked / circular）を判定する。
サブエージェントには、Issue一覧のJSONデータをそのまま渡すこと。

サブエージェントの結果から、各Issueの依存状態を把握した上でステップ2に進む。

### 2. 各Issueのトリアージ

ステップ1で取得したresolvedステータスのIssueに対して、それぞれ`issue-triage-processor` サブエージェントを起動し、トリアージ処理を委譲する。
エージェントは**並列で**実行する。

各Issueに対して以下の情報を渡すこと：

- 対象Issue番号
- Issueのラベル一覧
- 依存関係の状態（resolved / blocked / circular）
- リポジトリのowner/repo

サブエージェントが各Issueの最後のコメント確認、パターン判定、ラベル付与を実行する。

### 3. 結果の報告

処理結果を以下の形式で報告してください。

- 処理したIssueの総数
- パターンA（確認事項への回答が必要）: Issue番号の一覧
- パターンB（Issue詳細の作成が必要）: Issue番号の一覧
- パターンC（実行可能）: Issue番号の一覧
- パターンD（依存待ち）: Issue番号の一覧と依存チェーン（例: #10 → #5 → #3）
