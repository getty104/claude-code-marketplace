# claude-code-marketplace

getty104's Claude Code Plugin Marketplace

## Overview

getty104 の Claude Code プラグインマーケットプレイスです。

## Plugins

| Plugin | 説明 |
|---|---|
| agent-access | Bitwarden Agent Access で保管庫の認証情報を承認付きで受け取り、コマンドやブラウザログインに安全に注入するスキル |

```bash
/plugin install agent-access --marketplace getty104/claude-code-marketplace
```

## Installation

### Prerequisites

- [Claude Code CLI](https://docs.claude.com/en/docs/claude-code/installation)

### 全プラグインを一括インストール

```bash
curl -fsSL https://raw.githubusercontent.com/getty104/claude-code-marketplace/main/install.sh | bash
```

Marketplace を追加（追加済みなら更新）し、登録されている全プラグインをインストールします。

### Marketplace の追加

```bash
claude marketplace add https://github.com/getty104/claude-code-marketplace
```

または `~/.config/claude/settings.json` に直接追加：

```json
{
  "plugin_marketplaces": [
    "https://github.com/getty104/claude-code-marketplace"
  ]
}
```

## Directory Structure

```
claude-code-marketplace/
├── .claude-plugin/
│   └── marketplace.json
└── agent-access/
    ├── .claude-plugin/plugin.json
    └── skills/agent-access/
        ├── SKILL.md
        ├── references/        # ブラウザツール別の認証手順
        └── scripts/
```

## License

MIT

## Author

getty104
