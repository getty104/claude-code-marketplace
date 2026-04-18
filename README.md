# claude-code-marketplace

getty104's Claude Code Plugin Marketplace

## Overview

GitHub Issue の実装・PR レビュー対応・Issue 管理などを自動化する Claude Code プラグインマーケットプレイスです。

あわせて [claude-task-worker](https://github.com/getty104/claude-task-worker) を利用すると、GitHub ラベルをトリガーに本プラグインのスキルを自動起動できます。

## Installation

### Prerequisites

- [Claude Code CLI](https://docs.claude.com/en/docs/claude-code/installation)
- [GitHub CLI (`gh`)](https://cli.github.com/)

### 1. Marketplace の追加

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

### 2. Plugin のインストール

```bash
claude plugin install base-tools
```

## Usage

Claude Code CLI からスキルを直接呼び出します。

```bash
claude
> /exec-issue 123
> /fix-review-point 456
> /create-issue ユーザー認証機能を追加したい
```

## Skills

### Issue 管理

| Skill | Description |
|---|---|
| `/exec-issue <issue番号>` | Issue を読み込み、実装から PR 作成まで自動化 |
| `/create-issue <タスク内容>` | タスク要件を分析し、実装プラン付き GitHub Issue を作成 |
| `/update-issue <Issue番号> <依頼内容>` | 既存 Issue の description を更新 |
| `/breakdown-issues <タスク内容>` | 要件を TODO に分解し、タスクごとに GitHub Issue を作成 |
| `/read-github-issue <issue番号>` | Issue の内容を取得し実装プランを作成 |
| `/answer-issue-questions <issue番号>` | Issue の確認事項をコードベース調査に基づき回答 |

### PR・レビュー対応

| Skill | Description |
|---|---|
| `/fix-review-point <PR番号>` | 未解決のレビューコメントに対応 |
| `/create-pr` | PR テンプレートを使用して GitHub PR を作成 |
| `/create-review-fix-plan` | 未解決レビューコメントと CI ステータスから修正プランを作成 |
| `/resolve-pr-comments` | PR の未解決 Review threads を一括 Resolve |
| `/check-dependabot <PR番号>` | Dependabot PR の変更内容を確認し、必要ならコード修正して push |

### トリアージ

| Skill | Description |
|---|---|
| `/triage-issue <Issue番号>` | Issue をトリアージし、依存関係や確認事項に応じたラベルを付与 |
| `/triage-pr <PR番号>` | PR のコンフリクト解消・修正プラン評価・マージ判定を実行 |

### 開発ツール

| Skill | Description |
|---|---|
| `/commit-push` | 適切な git コミット戦略でコミット＆プッシュ |
| `/check-library` | MCP サーバー経由でライブラリドキュメントを取得 |
| `/create-task-summary` | 直近一週間の PR からサマリーを作成 |

## Agents

| Agent | Description |
|---|---|
| `general-purpose-assistant` | 汎用的な問題解決とタスク実行 |
| `requirement-todo-organizer` | タスクを要件と依存関係付き TODO リストに分解 |
| `frontend-implementer` | デザインシステムやコンポーネントに沿ってフロントエンド UI を実装 |

## MCP Servers

base-tools プラグインに含まれる `.mcp.json` により、以下の MCP サーバーが自動設定されます。

| Server | Description |
|---|---|
| `chrome-devtools` | ブラウザ自動化と DevTools 統合 |
| `context7` | ライブラリドキュメント取得（API キー不要） |
| `next-devtools` | Next.js 開発ツールとドキュメント |
| `shadcn` | shadcn/ui コンポーネントライブラリ統合 |

## Directory Structure

```
claude-code-marketplace/
├── .claude-plugin/
│   └── marketplace.json
└── base-tools/
    ├── .claude-plugin/
    │   └── plugin.json
    ├── .mcp.json
    ├── agents/
    │   ├── frontend-implementer.md
    │   ├── general-purpose-assistant.md
    │   └── requirement-todo-organizer.md
    ├── skills/
    │   ├── answer-issue-questions/
    │   ├── breakdown-issues/
    │   ├── check-dependabot/
    │   ├── check-library/
    │   ├── commit-push/
    │   ├── create-issue/
    │   ├── create-pr/
    │   ├── create-review-fix-plan/
    │   ├── create-task-summary/
    │   ├── exec-issue/
    │   ├── fix-review-point/
    │   ├── read-github-issue/
    │   ├── resolve-pr-comments/
    │   ├── triage-issue/
    │   ├── triage-pr/
    │   └── update-issue/
    ├── hooks/
    │   └── hooks.json
    └── scripts/
        └── setup-worktree.sh
```

## Customization

### Skill の追加

`base-tools/skills/` にディレクトリを作成し、`SKILL.md` を配置：

```markdown
---
name: skill-name
description: スキルの説明
model: sonnet
---

スキルのプロンプト内容
```

### Agent の追加

`base-tools/agents/` に `.md` ファイルを作成：

```markdown
---
name: agent-name
description: エージェントの説明
model: inherit
---

エージェントのプロンプト内容
```

### MCP Server の追加

`base-tools/.mcp.json` にサーバーを追加：

```json
{
  "mcpServers": {
    "server-name": {
      "command": "npx",
      "args": ["-y", "package-name"]
    }
  }
}
```

## Validation

```bash
claude plugin validate base-tools/
claude plugin install ./base-tools
```

## License

MIT

## Author

getty104
