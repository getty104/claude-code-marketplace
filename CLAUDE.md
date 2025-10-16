# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

このリポジトリは、getty104のClaude Codeマーケットプレイスプラグインです。TDD（テスト駆動開発）ベースの開発ワークフローを自動化するカスタムエージェント、コマンド、フックを提供します。

## アーキテクチャ

### ディレクトリ構造

```
claude-code-marketplace/
├── .claude-plugin/
│   └── marketplace.json        # マーケットプレイスのメタデータ
├── getty104/                   # メインプラグイン
│   ├── .mcp.json              # MCP設定（playwright, serena, context7）
│   ├── agents/                # カスタムエージェント定義
│   │   ├── github-issue-implementer.md
│   │   └── review-comment-implementer.md
│   ├── commands/              # スラッシュコマンド定義
│   │   ├── exec-issue.md
│   │   ├── fix-review-point.md
│   │   └── fix-review-point-loop.md
│   └── hooks/                 # イベントフック
│       └── hooks.json
```

### カスタムエージェント

#### github-issue-implementer
GitHub Issueから実装してPRを作成する専門エージェント。以下の責務を持ちます：
- Issue内容の分析と実装計画の作成
- TDDサイクル（テスト作成 → 失敗確認 → 実装 → 成功確認）の実行
- `npm run lint`による品質チェック
- PR作成（`@.github/PULL_REQUEST_TEMPLATE.md`に従う）
- `docker compose down`による後処理

#### review-comment-implementer
レビューコメントの実装を専門とするエージェント。以下の機能を提供：
- GitHub GraphQL APIを使用したResolveしていないレビューコメントの取得
- TDDアプローチでの指摘事項の修正
- レビューコメントのResolve処理
- `/gemini review`コメントによる再レビュー依頼
- `docker compose down`による後処理

### コマンドワークフロー

すべてのコマンドは`git worktree`を活用し、メインブランチから独立した環境で作業します：

1. **git-worktreeの準備フロー**
   - mainブランチを最新化
   - `.git-worktrees/`配下に新規worktreeを作成
   - `.env`ファイルのコピー
   - worktree内でSerenaアクティベート
   - メモリのコピー（`cp -r ../../.serena/memories .serena/memories`）
   - 依存パッケージのインストール

2. **コマンド実行時の制約**
   - すべての作業はworktree内で実行
   - `cd`使用時は`pwd`で現在地を必ず確認
   - worktree外でのコード変更は厳禁

### MCP設定

プロジェクトで使用される3つのMCPサーバー：
- **playwright**: ブラウザ自動化
- **serena**: コードベース解析とセマンティック操作
- **context7**: ライブラリドキュメントの取得

## 開発規約

### TDD（テスト駆動開発）
1. テスト作成（テスト対象ファイルと同じディレクトリに配置）
2. テスト実行（失敗確認）
3. 実装
4. テスト実行（成功確認）
5. リファクタリング

### コード品質基準
- すべてのテストが通ること
- `npm run lint`でエラーゼロ
- TypeScript型安全性の確保
- レイヤーアーキテクチャ（モデル、インフラ、アプリケーション、プレゼンテーション）の遵守
- コメント禁止（コードは自己説明的であるべき）
- 必要最小限のファイル変更

### レイヤーアーキテクチャ
プロジェクトは以下の4層構造を採用：
- **モデル層**: ビジネスロジックとドメインモデル
- **インフラストラクチャ層**: データベース、外部API等の実装
- **アプリケーション層**: ユースケースの実装
- **プレゼンテーション層**: UI/APIレスポンス

## 使用方法

### Issue実装フロー
```bash
/exec-issue <issue番号>
```
GitHub Issueを読み込み、worktreeを作成して実装からPR作成まで自動化します。

### レビューコメント対応フロー
```bash
/fix-review-point <ブランチ名>
```
指定ブランチのResolveされていないレビューコメントに対応します。

### レビューコメント完全対応フロー
```bash
/fix-review-point-loop <ブランチ名>
```
レビューコメントがなくなるまで繰り返し対応します（5分間隔でチェック）。

## プロジェクトファイルの編集

### エージェントの追加・編集
`getty104/agents/`配下に`.md`ファイルを作成し、以下の形式で記述：
```markdown
---
name: agent-name
description: エージェントの説明
model: sonnet
color: cyan
---
エージェントのプロンプト内容
```

### コマンドの追加・編集
`getty104/commands/`配下に`.md`ファイルを作成し、コマンドの処理内容を記述。

### フックの設定
`getty104/hooks/hooks.json`でイベントフック（Stop等）を設定。現在はStop時に音声通知を実装。
