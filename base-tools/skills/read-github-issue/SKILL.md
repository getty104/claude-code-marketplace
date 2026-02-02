---
name: read-github-issue
description: GitHub Issueの内容を取得し、実装プランを作成します。
model: sonnet
argument-hint: "[issue-number]"
---

# Read GitHub Issue

GitHub Issueの内容を取得し、実装プランを作成します。

# Instructions

## 実行ステップ

### 1. Issueの取得

以下のコマンドでGitHub Issueの内容を取得します。

```
gh issue view $ARGUMENTS
```

#### Issue内容取得時の重要なルール

Issue内に画像リンクがある場合は gh-asset を使って画像をダウンロードし、その画像の情報も読み込むこと。

```
gh-asset download <asset_id> ~/Downloads/
```

- 参考: https://github.com/YuitoSato/gh-asset

### 2. 実装プランの作成

取得したIssue内容をもとに、実装プランを作成します。
実装プランは以下のステップで作成してください。

- Exploreサブエージェントを使用して、Issueの内容を分析します。
- Planサブエージェントを使用して、具体的な実装プランを策定します。

#### 実装プラン作成時の重要なルール

- 各タスクはgeneral-purpose-assistantサブエージェントで実装する旨を明記すること
- プランは具体的かつ実行可能なステップに分解すること
- プランは優先順位順に並べること
