---
name: bump-version
description: base-toolsプラグインのバージョン（patchバージョン）をインクリメントし、commit-pushでコミット・プッシュする。「バージョンを上げて」「バージョンアップ」「bump version」などのリクエストで使用する。
disable-model-invocation: true
---

# Bump Version

`base-tools/.claude-plugin/plugin.json` のpatchバージョンをインクリメントし、変更をコミット・プッシュするスキルです。

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

`/base-tools:commit-push` スキルを呼び出して、変更をコミット・プッシュする。
