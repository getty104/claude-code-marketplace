---
name: resolve-pr-comments
description: GitHub PRの未解決Review threadsを一括Resolveします。GraphQL APIで未解決のReview threads（コード特定行へのコメント）を取得し、resolveReviewThread mutationで全て自動的にResolveします。Issue comments（会話タブ）は元々Resolve機能がないため対象外です。各スレッドのResolve結果を表示します。
model: haiku
agent: general-purpose
context: fork
---

# Resolve PR Comments

## Instructions

以下のコマンドでResolveしていないレビューコメントをResolveします。
scriptsディレクトリはプラグイン内のskills/resolve-pr-comments/配下に配置されています。

```
bash /プラグインルートパス/skills/resolve-pr-comments/scripts/resolve-pr-comments.sh
```
