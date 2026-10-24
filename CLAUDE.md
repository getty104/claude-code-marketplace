# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

このリポジトリはClaude Code Plugin Marketplaceです。登録プラグイン: `agent-access`（Bitwarden Agent Access のスキル。ブラウザツール別の認証手順は `skills/agent-access/references/` に1ツール1ファイルで追加する）

## プラグイン検証コマンド

### プラグインの検証
```bash
claude plugin validate <プラグインディレクトリ>/
```

### ローカルでのテストインストール
```bash
claude plugin install ./<プラグインディレクトリ>
```

## アーキテクチャと構成

### Marketplace構造

```
claude-code-marketplace/
├── .claude-plugin/
│   └── marketplace.json          # Marketplaceメタデータ（pluginsにプラグインを登録）
└── agent-access/                 # プラグイン
```

## 品質基準

- すべてのテストが通ること
- `npm run lint`でエラーなし
- TypeScript型安全性の確保
- **コメントは一切残さない**（コードは自己説明的であるべき）
- 必要最小限のファイル変更
- ドキュメントファイル（*.md）は明示的に要求された場合のみ作成

## プラグイン開発ガイドライン

### Agentの追加

`agents/`ディレクトリに`.md`ファイルを作成し、frontmatterで定義：

```markdown
---
name: agent-name
description: エージェントが使用される条件の明確な説明
model: inherit  # または sonnet など
color: cyan
---

エージェントのプロンプト内容
```

**重要**: `description`はClaude Codeが自動的にエージェントを起動する判断基準になるため、明確かつ具体的に記述する

### Hooksの設定

`hooks/hooks.json`でイベントハンドラを設定：
- 利用可能なイベント: `PreToolUse`, `PostToolUse`, `Stop`など

### MCPサーバーの追加

`.mcp.json`に新しいサーバーを追加：

```json
{
  "mcpServers": {
    "server-name": {
      "command": "command",
      "args": ["arg1", "arg2"]
    }
  }
}
```

### Skillの追加

`skills/`ディレクトリに新しいディレクトリを作成し、`SKILL.md`ファイルを配置：

```
skills/
└── my-skill/
    ├── SKILL.md          # スキル定義（必須）
    ├── examples.md       # 使用例（オプション）
    └── reference.md      # リファレンス（オプション）
    └── scripts/          # スクリプト（オプション）
```

`SKILL.md`のfrontmatterで定義：

```markdown
---
name: skill-name
description: スキルの説明（Claudeが自動呼び出しの判断に使用）
disable-model-invocation: true  # ユーザー呼び出し専用にする場合
argument-hint: "[引数の説明]"    # オートコンプリート時に表示
---

スキルのプロンプト内容
```

**フロントマターのフィールド**:
- `name`: スキル名（省略時はディレクトリ名）
- `description`: スキルの説明（Claudeが自動呼び出しの判断に使用）
- `disable-model-invocation`: `true`でClaude自動呼び出しを無効化（ユーザー専用）
- `user-invocable`: `false`で`/`メニューから非表示（Claude専用）
- `argument-hint`: オートコンプリート時に表示する引数ヒント
- `allowed-tools`: スキル実行時に許可するツールのリスト
- `context`: `fork`でサブエージェントとして実行
- `agent`: `context: fork`時に使用するエージェントタイプ
