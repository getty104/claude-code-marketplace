---
name: read-github-issue
description: GitHub Issueの内容を取得し、実装プランを作成します。
model: opus
context: fork
agent: general-purpose
argument-hint: "[issue-number]"
---

# Read GitHub Issue

GitHub Issueの内容を取得し、実装プランを作成するためのスキルです。
このスキルが呼び出された際には、Instructionsに従って、Issueの内容を取得し、実装プランの作成を行ってください。

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

- Issueの内容を詳細に分析する
  - Issueで要求されている機能や改善点を特定する
  - 要件の背景や目的を理解する
  - 実装が必要なコード箇所を特定する
- 分析した内容をもとに、具体的な実装プランを策定する

#### 実装プラン作成時の重要なルール

- プランは具体的かつ並列実行可能な単位で分解すること
