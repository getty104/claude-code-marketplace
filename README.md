# claude-code-marketplace

getty104's Claude Code Plugin Marketplace

## Overview

getty104 の Claude Code プラグインマーケットプレイスです。

## Plugins

| Plugin | 説明 |
|---|---|
| agent-access | Bitwarden Agent Access で保管庫の認証情報を承認付きで受け取り、コマンドやブラウザログインに安全に注入するスキル |
| bitwarden-cli | Bitwarden CLI（bw）を API キーでログインし、BW_ 系の環境変数と保管庫の値を会話に出さずにコマンドやブラウザログインへ使うスキル |

```bash
/plugin install agent-access --marketplace getty104/claude-code-marketplace
/plugin install bitwarden-cli --marketplace getty104/claude-code-marketplace
```

bitwarden-cli の `permissions.deny` はプラグインからは適用されないため、[`bitwarden-cli/skills/bitwarden-cli/settings.json`](bitwarden-cli/skills/bitwarden-cli/settings.json) の内容を `~/.claude/settings.json` などに追記してください。

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
└── bitwarden-cli/
    ├── .claude-plugin/plugin.json
    ├── hooks/                 # クラウドで bw を入れる SessionStart フックと、BW_ 系環境変数の出力を止める PreToolUse フック
    └── skills/bitwarden-cli/
        ├── SKILL.md
        ├── settings.json      # ユーザーの settings.json に追記する deny ルール
        ├── references/
        └── scripts/
```

## License

MIT

## Author

getty104
