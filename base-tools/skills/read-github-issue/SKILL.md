---
name: read-github-issue
description: GitHub Issueの内容を取得し、並列実行可能な単位に分解します。
model: sonnet
effort: high
context: fork
argument-hint: "[issue-number]"
---

# Read GitHub Issue

GitHub Issueの内容を取得し、並列実行可能な単位に分解するスキルです。

# Instructions

## 1. Issueの取得

```
gh issue view $ARGUMENTS
```

Issue内に画像リンクがある場合は `gh-asset` で画像をダウンロードし、内容を読み込むこと。

```
gh-asset download <asset_id> ~/Downloads/
```

参考: https://github.com/YuitoSato/gh-asset

## 2. タスクの分解

取得したIssueの内容を、並列実行可能な単位に分解する。

## 3. 呼び出し元への返却

以下を構造化して返却すること。

- **Issue概要**: タイトル・目的・背景の要約
- **分解タスク一覧**: 並列実行可能な単位のタスクリスト（各タスクに目的・対象範囲・完了条件を明記）
- **タスク間の依存関係**: 並列実行可能なグループと、逐次実行が必要な依存関係
- **参考情報**: Issueリンク、関連する画像・資料のパス
