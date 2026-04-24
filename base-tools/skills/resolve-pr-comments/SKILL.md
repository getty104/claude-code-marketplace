---
name: resolve-pr-comments
description: GitHub PRの未解決Review threadsを一括Resolveします。
model: haiku
context: fork
---

# Resolve PR Comments

GitHubのプルリクエスト（PR）における未解決のレビューコメントを一括でResolveします。

# Instructions

以下のコマンドでResolveしていないレビューコメントをResolveします。

```
bash ${CLAUDE_SKILL_DIR}/scripts/resolve-pr-comments.sh
```
