---
name: read-github-issue
description: GitHub Issueの内容を取得し、並列実行可能な単位に分解します。
model: opus
effort: medium
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
