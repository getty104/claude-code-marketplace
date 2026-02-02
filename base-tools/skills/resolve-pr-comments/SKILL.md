---
name: resolve-pr-comments
description: GitHub PRの未解決Review threadsを一括Resolveします。
model: haiku
agent: general-purpose
context: fork
---

# Resolve PR Comments

GitHubのプルリクエスト（PR）における未解決のレビューコメントを一括でResolveします。

# Instructions

以下のコマンドでResolveしていないレビューコメントをResolveします。
scriptsディレクトリはプラグイン内のskills/resolve-pr-comments/配下に配置されています。

```
bash /プラグインルートパス/skills/resolve-pr-comments/scripts/resolve-pr-comments.sh
```
