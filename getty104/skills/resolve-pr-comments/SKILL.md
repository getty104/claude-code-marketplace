---
name: resolve-pr-comments
description: GitHub PRの未解決Review threadsを一括Resolveします。GraphQL APIで未解決のReview threads（コード特定行へのコメント）を取得し、resolveReviewThread mutationで全て自動的にResolveします。Issue comments（会話タブ）は元々Resolve機能がないため対象外です。各スレッドのResolve結果を表示します。
---

# Resolve PR Comments

## Instructions
scripts/read-unresolved-pr-comments.sh スクリプトで取得した未解決のReview threadsを一括でResolveします。
このスクリプトを実行することで、PRの未解決コメントを簡単に解決できます。
