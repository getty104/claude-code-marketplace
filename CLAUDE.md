# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

このリポジトリはClaude Code Plugin Marketplaceであり、TDD（テスト駆動開発）ベースの開発ワークフローを自動化する専用プラグインを提供します。

**重要な特徴**:
- **Marketplace形式**: 複数のプラグインを一元管理し、チームやコミュニティと簡単に共有できる
- **git worktree活用**: mainブランチから分離された安全な作業環境を提供
- **MCP統合**: chrome-devtools（ブラウザ自動化）、context7（ライブラリドキュメント取得）、next-devtools（Next.js開発ツール）、shadcn（shadcn/ui統合）のMCPサーバーを統合

## プラグイン検証コマンド

### プラグインの検証
```bash
claude plugin validate getty104/
```

### ローカルでのテストインストール
```bash
claude plugin install ./getty104
```

## アーキテクチャと構成

### Marketplace構造

```
claude-code-marketplace/
├── .claude-plugin/
│   └── marketplace.json          # Marketplaceメタデータ
└── getty104/                      # getty104プラグイン
    ├── .claude-plugin/            # 自動生成される
    ├── .mcp.json                  # MCP設定
    ├── agents/                    # サブエージェント
    ├── commands/                  # スラッシュコマンド
    └── hooks/                     # イベントハンドラ
```

### プラグインの4つのコンポーネント

1. **Agents** (`agents/*.md`): 特定のタスクに特化したサブエージェント
   - `github-issue-implementer`: Issue実装とPR作成
   - `review-comment-implementer`: レビューコメント対応
   - `general-purpose-assistant`: 汎用的な問題解決とタスク実行

2. **Commands** (`commands/*.md`): カスタムスラッシュコマンド
   - `/exec-issue <issue番号>`: Issueを読み込み、実装からPR作成まで自動化
   - `/fix-review-point <ブランチ名>`: 未解決のレビューコメントへの対応
   - `/fix-review-point-loop <ブランチ名>`: レビューコメントがなくなるまで繰り返し対応
   - `/general-task <タスク内容>`: general-purpose-assistantを使用して汎用タスクを実行

3. **Hooks** (`hooks/hooks.json`): イベントハンドラの設定

4. **MCP Servers** (`.mcp.json`): 外部ツール統合
   - `chrome-devtools`: ブラウザ自動化とDevTools統合
   - `context7`: ライブラリドキュメント取得（HTTPベース）
   - `next-devtools`: Next.js開発ツールとドキュメント
   - `shadcn`: shadcn/uiコンポーネントライブラリ統合

### git worktree ワークフロー

このマーケットプレイスの核となる機能は、git worktreeを利用した分離された作業環境です：

1. `.git-worktrees/`ディレクトリに新しいworktreeを作成
2. ブランチ名には`/`を含めない（worktree名の生成時に`tr '/' '-'`で変換）
3. `.env`ファイルをworktreeにコピー
4. 必要なセットアップ（npm installなど）を実行
5. すべての作業をworktree内で完結
6. 完了後は`docker compose down`でコンテナを停止

### TDD実装フロー

すべての実装タスクは以下のTDDサイクルに従います：

1. テスト作成（テスト対象のファイルと同じディレクトリに配置）
2. テスト実行（失敗確認 - Red）
3. 実装
4. テスト実行（成功確認 - Green）
5. 必要に応じてリファクタリング
6. `npm run lint`でコード品質チェック
7. エラーがなくなるまで修正

### PR作成ルール

PRを作成する際は以下のルールに従う：
- PRのdescriptionテンプレートは `.github/PULL_REQUEST_TEMPLATE.md` を参照（存在する場合）
- テンプレート内のコメントアウト箇所は削除
- descriptionに`Closes #<issue番号>`を記載

### レビューコメント対応ワークフロー

1. 未解決のレビューコメントを取得（GraphQL API使用）
2. TDDアプローチで修正
3. テストとLintを実行
4. コミット作成とpush
5. レビューコメントをResolve（GraphQL mutation使用）
6. `/gemini review`コメントでPRに再レビューを依頼
7. `docker compose down`で終了

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

### Commandの追加

`commands/`ディレクトリに`.md`ファイルを作成：
- ファイル名がコマンド名になる
- `$ARGUMENTS`変数で引数を参照可能
- Markdownで処理内容とステップを記述

### Hooksの設定

`hooks/hooks.json`でイベントハンドラを設定：
- 利用可能なイベント: `PreToolUse`, `PostToolUse`, `Stop`など
- 現在は`Stop`イベントでサウンド通知を設定

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
