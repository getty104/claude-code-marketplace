---
name: read-unresolved-pr-comments
description: GitHub PRから未対応のコメントを取得します。GraphQL APIで (1) コード特定行への未解決Review threads（Resolve可能）と (2) コードブロックを含むIssue comments（会話タブ、Resolve不可）の両方を取得し、JSON形式で出力します。PR情報（番号・タイトル・URL・状態・作成者・レビュアー）も含まれます。
model: haiku
agent: general-purpose
context: fork
---

# Read Unresolved PR Comments

## Instructions
以下のコマンドを実行して、未解決のプルリクエストレビューコメントを取得します。
scriptsディレクトリはプラグイン内のskills/read-unresolved-pr-comments/配下に配置されています。

```
bash /プラグインルートパス/skills/read-unresolved-pr-comments/scripts/read-unresolved-pr-comments.sh 
```
