# claude-code-marketplace

getty104's Claude Code Plugin Marketplace

## Overview

getty104 の Claude Code プラグインマーケットプレイスです。現在登録されているプラグインはありません。

## Installation

### Prerequisites

- [Claude Code CLI](https://docs.claude.com/en/docs/claude-code/installation)

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
└── .claude-plugin/
    └── marketplace.json
```

## License

MIT

## Author

getty104
