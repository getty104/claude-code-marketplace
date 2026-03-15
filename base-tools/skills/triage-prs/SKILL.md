---
name: triage-prs
description: Triage open GitHub PRs assigned to the user. Fetch PRs where CI has completed and cc-in-progress label is not present, run create-review-fix-plan for each, then either add cc-fix-onetime label (if fixes are needed) or merge the PR (if it's ready to merge as-is).
argument-hint: ""
model: opus
---

# Triage PRs

ユーザーにアサインされたオープンなPRを取得し、CIが完了済みかつ`cc-in-progress`と`cc-fix-onetime`ラベルがついていないPRに対して修正プランを確認し、適切なアクション（ラベル付与またはマージ）を実行するスキルです。

# Instructions

## 実行ステップ

### 1. ユーザー情報の取得

```
gh api user --jq '.login'
```

### 2. 対象PR一覧の取得

ユーザーにアサインされたオープンなPRを取得してください。

```
gh pr list --assignee <ユーザー名> --state open --json number,title,url,labels,headRefName,statusCheckRollup,reviewDecision --limit 100
```

取得したPRから以下の条件で**すべて**を満たすものだけをフィルタしてください。

- `cc-in-progress`と`cc-fix-onetime`ラベルどちらも**ついていない**
- `statusCheckRollup`のすべてのチェックが完了している（`status`が`COMPLETED`）
  - チェックが存在しないPRも対象に含める

### 3. 各PRに対するループ処理

フィルタされた**すべてのPR**に対して、`pr-triage-processor` エージェントをAgent toolでトリアージ処理を行なってください。
エージェントは**並列で**実行してください。

各PRについて、以下の情報をエージェントに渡してください：

- PR番号
- PRタイトル
- ブランチ名（headRefName）

エージェントがPRの分析（ブランチのcheckout、コンフリクト確認・解消、修正プラン確認、判定）とアクション（ラベル付与またはマージ）を実行します。すべてのエージェントの結果を収集してください。

各エージェントが作成したworktreeは、エージェントの処理が完了した後にまだ残っていれば削除してください。

### 4. 結果の報告

処理結果を以下の形式で報告してください。

- 処理したPRの総数
- パターンA（修正が必要）: PR番号とタイトルの一覧、修正が必要な理由の要約
- パターンB（マージ済み）: PR番号とタイトルの一覧
- 対象外（フィルタで除外）: PR番号とタイトルの一覧、除外理由
