---
name: read-unresolved-pr-comments
description: GitHub PRから未対応のコメントを取得し、修正プランを作成します。
model: sonnet
context: fork
agent: general-purpose
---

# Read Unresolved PR Comments

GitHubのプルリクエスト（PR）から未解決のレビューコメントを取得し、修正プランを作成します。

# Instructions

## 実行ステップ

### 1. 未解決のプルリクエストレビューコメントの取得

以下のコマンドを実行して、未解決のプルリクエストレビューコメントを取得します。
scriptsディレクトリはプラグイン内のskills/read-unresolved-pr-comments/配下に配置されています。

```
bash /プラグインルートパス/skills/read-unresolved-pr-comments/scripts/read-unresolved-pr-comments.sh 
```

### 2. 修正プランの作成

取得した未解決コメントをもとに、修正プランを作成します。
修正プランは以下のステップで作成してください。

- 未解決コメントの内容を詳細に分析する
  - コメントが指摘している問題点や改善点を特定する
  - コメントの背景や意図を理解する
  - 修正が必要なコード箇所を特定する
- 分析した内容をもとに、具体的な修正プランを策定する

#### 修正プラン作成時の重要なルール

- プランは具体的かつ並列実行可能な単位で分解すること
