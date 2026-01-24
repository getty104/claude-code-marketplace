---
name: read-unresolved-pr-comments
description: GitHub PRから未対応のコメントを取得し、修正プランを作成します。
model: sonnet
agent: Plan
context: fork
---

# Read Unresolved PR Comments

## Instructions

以下のステップに従って、GitHubプルリクエストから未対応のコメントを取得し、修正プランを作成します。

### 未解決のプルリクエストレビューコメントの取得

以下のコマンドを実行して、未解決のプルリクエストレビューコメントを取得します。
scriptsディレクトリはプラグイン内のskills/read-unresolved-pr-comments/配下に配置されています。

```
bash /プラグインルートパス/skills/read-unresolved-pr-comments/scripts/read-unresolved-pr-comments.sh 
```

### 修正プランの作成

取得した未解決コメントをもとに、修正プランを作成します。修正プランには、各コメントに対する具体的な対応策やコード変更の提案を含めます。
