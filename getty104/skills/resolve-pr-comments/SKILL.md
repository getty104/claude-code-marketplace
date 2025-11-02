---
name: resolve-pr-comments
description: GitHub PRの未解決Review threadsを一括Resolveします。GraphQL APIで未解決のReview threads（コード特定行へのコメント）を取得し、resolveReviewThread mutationで全て自動的にResolveします。Issue comments（会話タブ）は元々Resolve機能がないため対象外です。各スレッドのResolve結果を表示します。
---

# Resolve PR Comments

## Instructions

以下のコマンドでResolveしていないレビューコメントをResolveします。

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/resolve-pr-comments.sh
```
