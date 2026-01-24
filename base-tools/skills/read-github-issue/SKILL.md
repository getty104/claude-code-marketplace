---
name: read-github-issue
description: GitHub Issueの内容を取得します。ghコマンドを使用してIssueのタイトル、本文、コメント、ラベル、アサイン情報などを取得します。
model: haiku
agent: general-purpose
context: fork
argument-hint: "[issue-number]"
---

# Read GitHub Issue

## Instructions

### Issueの取得
以下のコマンドでGitHub Issueの内容を取得します。

```
gh issue view $ARGUMENTS
```

### 画像のダウンロード
Issue内に画像リンクがある場合は gh-asset を使って画像をダウンロードし、その画像の情報も読み込みます
- `gh-asset download <asset_id> ~/Downloads/`
- 参考: https://github.com/YuitoSato/gh-asset
