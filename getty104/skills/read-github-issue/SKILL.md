---
name: read-github-issue
description: GitHub Issueの内容を取得します。ghコマンドを使用してIssueのタイトル、本文、コメント、ラベル、アサイン情報などを取得します。
---

# Read GitHub Issue

## Instructions

### Issueの取得
以下のコマンドでGitHub Issueの内容を取得します。
scriptsディレクトリはプラグイン内のskills/create-git-worktree/配下に配置されています。

```
gh view issue [Issue番号]
```

### 画像のダウンロード
Issue内に画像リンクがある場合は gh-asset を使って画像をダウンロードし、その画像の情報も読み込みます
- `gh-asset download <asset_id> ~/Downloads/`
- 参考: https://github.com/YuitoSato/gh-asset
