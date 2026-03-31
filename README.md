# claude-code-marketplace

getty104's Claude Code Plugin Marketplace

## Overview

[claude-task-worker](https://github.com/getty104/claude-task-worker) と組み合わせて使用することで、GitHub Issue の実装からPRのレビュー対応までを自動化する Claude Code プラグインマーケットプレイスです。

claude-task-worker が GitHub のラベルを検知してタスクを起動し、本マーケットプレイスの base-tools プラグインが実際の実装・レビュー対応・Issue 管理を担います。

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   GitHub                            │
│  Issue (cc-exec-issue)  ──┐                         │
│  Issue (cc-create-issue) ─┤                         │
│  Issue (cc-update-issue) ─┤    ┌──────────────────┐ │
│  PR (cc-fix-onetime)    ──┼───▶│claude-task-worker│ │
│  PR (cc-fix-repeat)     ──┘    └────────┬─────────┘ │
└─────────────────────────────────────────┼───────────┘
                                          │ invoke
                                          ▼
                               ┌─────────────────────┐
                               │    Claude Code CLI   │
                               │  + base-tools plugin │
                               └─────────────────────┘
```

claude-task-worker は以下のラベルをトリガーにしてタスクを検出し、Claude Code CLI 経由で base-tools のスキルを呼び出します。

| Label | Worker Command | 呼び出されるスキル |
|---|---|---|
| `cc-exec-issue` | `exec-issue` | `/exec-issue` |
| `cc-create-issue` | `create-issue` | `/create-issue` |
| `cc-update-issue` | `update-issue` | `/update-issue` |
| `cc-fix-onetime` | `fix-review-point` | `/fix-review-point` |
| `cc-fix-repeat` | `fix-review-point` | `/fix-review-point`（繰り返し） |

## Installation

### Prerequisites

- [Claude Code CLI](https://docs.claude.com/en/docs/claude-code/installation)
- [GitHub CLI (`gh`)](https://cli.github.com/)
- [claude-task-worker](https://github.com/getty104/claude-task-worker)

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

### 3. claude-task-worker のセットアップ

対象リポジトリで初期化を実行すると、必要なラベル・Issue テンプレート・GitHub Actions ワークフローが作成されます。

```bash
npx claude-task-worker init
```

### 4. Worker の起動

```bash
npx claude-task-worker all
```

すべてのワーカーが起動し、GitHub Issue/PR のポーリングが開始されます。

## Usage

### 自動実行（claude-task-worker 経由）

1. GitHub Issue を作成し、`cc-exec-issue` ラベルを付与
2. claude-task-worker が検知し、`/exec-issue` スキルを呼び出す
3. Issue の内容に基づいて自動実装 → PR 作成まで完了

### 手動実行（Claude Code CLI で直接呼び出し）

```bash
claude
> /exec-issue 123
> /fix-review-point feature-branch
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

### PR・レビュー対応

| Skill | Description |
|---|---|
| `/fix-review-point <ブランチ名>` | 未解決のレビューコメントに対応 |
| `/create-pr` | PR テンプレートを使用して GitHub PR を作成 |
| `/create-review-fix-plan` | 未解決レビューコメントと CI ステータスから修正プランを作成 |
| `/resolve-pr-comments` | PR の未解決 Review threads を一括 Resolve |

### トリアージ

| Skill | Description |
|---|---|
| `/triage-issues` | アサインされた Issue に適切なラベルを付与 |
| `/triage-prs` | CI 完了済み PR を確認し、修正ラベル付与またはマージ |

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
| `issue-dependency-analyzer` | GitHub Issue 間の依存関係グラフを構築し、依存状態（resolved / blocked / circular）を判定 |
| `issue-triage-processor` | 依存関係が解決済みの Issue に対してトリアージ処理（確認事項への回答・ラベル付与）を実行 |
| `pr-triage-processor` | トリアージ対象の PR を個別処理し、コンフリクト解消・修正プラン評価・マージ判定を実行 |

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
    │   ├── general-purpose-assistant.md
    │   ├── requirement-todo-organizer.md
    │   ├── issue-dependency-analyzer.md
    │   ├── issue-triage-processor.md
    │   └── pr-triage-processor.md
    ├── skills/
    │   ├── breakdown-issues/
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
    │   ├── triage-issues/
    │   ├── triage-prs/
    │   └── update-issue/
    ├── hooks/
    │   └── hooks.json
    └── scripts/
        └── remove-merged-worktrees.sh
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
