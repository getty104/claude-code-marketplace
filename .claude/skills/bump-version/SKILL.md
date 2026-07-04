---
name: bump-version
description: base-toolsプラグインのバージョン（patchバージョン）をインクリメントし、commit-pushでコミット・プッシュしたうえでPRを作成する。「バージョンを上げて」「バージョンアップ」「bump version」などのリクエストで使用する。
---

# Bump Version

`base-tools/.claude-plugin/plugin.json` のpatchバージョンをインクリメントし、変更をコミット・プッシュしたうえでPRを作成するスキルです。

## 実行ステップ

### ステップ1: 現在のバージョンを取得

以下のコマンドで現在のバージョンを取得：

```bash
cat base-tools/.claude-plugin/plugin.json | jq -r '.version'
```

### ステップ2: patchバージョンをインクリメント

取得したバージョン（例: `0.0.107`）のpatch部分を +1 して新しいバージョンを算出する。

### ステップ3: plugin.json を更新

`base-tools/.claude-plugin/plugin.json` の `version` フィールドを新しいバージョンに更新する。

### ステップ4: コミットとプッシュ

変更を現在のブランチにコミット・プッシュする。

### ステップ5: PRを作成

pushしたブランチから、デフォルトブランチへのPRを作成する。バージョンバンプはIssueに紐づかないchore作業のため、`create-pr` スキル（`Closes #<Issue>` と `cc-triage-scope` ラベルを前提とする）は使わず、`gh pr create` で直接作成する。

- タイトル: `chore(base-tools): Bump version to <新バージョン>`
- ベースブランチ: デフォルトブランチ（`gh repo view --json defaultBranchRef -q .defaultBranchRef.name`）
- Assignees: `gh api user --jq '.login'` で取得した自分自身
- 本文: バージョンを `<旧バージョン>` から `<新バージョン>` に更新した旨を記載

```bash
gh pr create \
  --title "chore(base-tools): Bump version to <新バージョン>" \
  --body "base-tools プラグインのバージョンを <旧バージョン> から <新バージョン> に更新。" \
  --base "$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)" \
  --assignee "$(gh api user --jq '.login')"
```

作成後、PRのURLを報告する。既に同一ブランチのPRが存在する場合は新規作成せず、そのURLを報告する。
