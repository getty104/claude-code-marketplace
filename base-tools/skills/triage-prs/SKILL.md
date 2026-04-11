---
name: triage-prs
description: Triage open GitHub PRs assigned to the user. Fetch PRs where CI has completed and cc-in-progress label is not present, run create-review-fix-plan for each, then either add cc-fix-onetime label (if fixes are needed) or merge the PR (if it's ready to merge as-is).
argument-hint: "[limit]"
model: sonnet
effort: high
---

# Triage PRs

ユーザーにアサインされたオープンなPRを取得し、CIが完了済みかつ`cc-fix-onetime`ラベルがついていないPRに対して修正プランを確認し、適切なアクション（ラベル付与またはマージ）を実行するスキルです。

# Instructions

## 実行ステップ

### 1. 対象PR一覧の確認

対象対象PR一覧は以下の通り。

!`gh pr list --assignee "$(gh api user --jq '.login')" --label "cc-triage-scope" --state open --json number,title,url,labels,headRefName,statusCheckRollup,reviewDecision --limit 100 --jq '[.[] | select(([.labels[].name] | any(. == "cc-fix-onetime")) | not) | select((.statusCheckRollup | length == 0) or (.statusCheckRollup | all(.status == "COMPLETED" or .state == "SUCCESS" or .state == "FAILURE" or .state == "ERROR")) or (.statusCheckRollup | any(.status == "FAILURE")))][:$0]'`

対象PRが0件の場合は、その旨を報告して終了する。

### 2. 各PRに対するトリアージ処理

上記の対象PR**すべて**に対して、`pr-triage-processor` エージェントをAgent toolでトリアージ処理を行う。
エージェントは**並列で**実行する。

各PRについて、以下の情報をエージェントに渡す：

- PR番号
- PRタイトル
- ブランチ名（headRefName）

エージェントがPRの分析（ブランチのcheckout、コンフリクト確認・解消、修正プラン確認、判定）とアクション（ラベル付与またはマージ）を実行する。すべてのエージェントの結果を収集する。

各エージェントが作成したworktreeは、エージェントの処理が完了した後にまだ残っていれば削除する。

### 3. 結果の報告

処理結果を以下の形式で報告する。

- 処理したPRの総数
- パターンA（修正が必要）: PR番号とタイトルの一覧、修正が必要な理由の要約
- パターンB（マージ済み）: PR番号とタイトルの一覧
