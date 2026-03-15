---
name: triage-prs
description: Triage open GitHub PRs assigned to the user. Fetch PRs where CI has completed and cc-in-progress label is not present, run create-review-fix-plan for each, then either add cc-fix-onetime label (if fixes are needed) or merge the PR (if it's ready to merge as-is).
argument-hint: ""
model: opus
---

# Triage PRs

ユーザーにアサインされたオープンなPRを取得し、CIが完了済みかつ`cc-in-progress`ラベルがついていないPRに対して修正プランを確認し、適切なアクション（ラベル付与またはマージ）を実行するスキルです。

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

- `cc-in-progress`ラベルが**ついていない**
- `statusCheckRollup`のすべてのチェックが完了している（`status`が`COMPLETED`）
  - チェックが存在しないPRも対象に含める

### 3. 各PRに対するループ処理

フィルタされた**すべてのPR**に対して、以下のステップ3a〜3dを**1件ずつ順番に**実行してください。1件のPRの処理が完了してから次のPRに進んでください。すべてのPRを処理し終えるまでループを終了しないでください。

#### 3a. ブランチのcheckoutとコンフリクト確認

対象PRのブランチにcheckoutしてください。

```
git checkout <PRのheadRefName>
```

checkoutしたら、originのベースブランチとコンフリクトしていないか確認してください。

```
git fetch origin main && git merge-tree $(git merge-base HEAD origin/main) HEAD origin/main
```

コンフリクトが検出された場合は、rebaseしてコンフリクトを解消してください。

```
git rebase origin/main
```

rebase中にコンフリクトが発生した場合は、コンフリクトを解消し、`git rebase --continue`で続行してください。rebase完了後、force-pushしてください。

```
git push origin HEAD --force-with-lease
```

#### 3b. 修正プラン確認

#### 3c. 修正プランに基づく判定とアクション

`create-review-fix-plan` skillを実行してください。その結果を pr-fix-plan-evaluator エージェントで分析し、以下の2パターンで判定し、**必ずどちらかのアクションを実行**してください。判定のみで終了せず、コマンドの実行まで確実に行ってください。

##### パターンA: 修正が必要な場合

修正が必要であると判断した場合、以下のコマンドを実行してPRに`cc-fix-onetime`ラベルを追加してください。

```
gh pr edit <PR番号> --add-label "cc-fix-onetime"
```

##### パターンB: マージ可能な場合

修正せずともマージできると判断した場合、**必ず以下のコマンドを実行してマージしてください。判定だけで終了しないでください。**

```
gh pr merge <PR番号> --merge --delete-branch
```

マージコマンドが失敗した場合は、エラー内容を記録して次のPRに進んでください。

#### 3d. 次のPRへ

このPRの処理結果（パターンA/B/エラー）を記録し、フィルタされたPRリストの次のPRに対してステップ3aから繰り返してください。**すべてのPRを処理し終えるまでループを終了しないでください。**

### 4. 結果の報告

処理結果を以下の形式で報告してください。

- 処理したPRの総数
- パターンA（修正が必要）: PR番号とタイトルの一覧、修正が必要な理由の要約
- パターンB（マージ済み）: PR番号とタイトルの一覧
- 対象外（フィルタで除外）: PR番号とタイトルの一覧、除外理由

## 注意事項

- 作業は全てworktree上で行い、mainブランチで作業は絶対に行わないこと
- ファイル編集などの作業を行う際は、pwdコマンドでworktree内部であることを確認してから行うこと
