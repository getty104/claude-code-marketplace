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
└── base-tools/                    # base-toolsプラグイン
    ├── .claude-plugin/            # 自動生成される
    ├── .mcp.json                  # MCP設定
    ├── agents/                    # サブエージェント
    ├── hooks/                     # イベントハンドラ
    ├── scripts/                   # シェルスクリプト
    └── skills/                    # スキル（スラッシュコマンド含む）
```

### プラグインの4つのコンポーネント

1. **Agents** (`agents/*.md`): 特定のタスクに特化したサブエージェント
   - `general-purpose-assistant`: 汎用的な問題解決とタスク実行
   - `task-requirement-analyzer`: タスク要件の分析と実装プラン策定
   - `pr-review-planner`: PRレビューコメントの分析と修正プラン作成

2. **Skills** (`skills/*/SKILL.md`): 再利用可能なスキル（スラッシュコマンド含む）

   **ユーザー呼び出し専用スキル（`disable-model-invocation: true`）**:
   - `/exec-issue <issue番号>`: Issueを読み込み、実装からPR作成まで自動化
   - `/fix-review-point <ブランチ名>`: 未解決のレビューコメントへの対応
   - `/fix-review-point-loop <ブランチ名>`: レビューコメントがなくなるまで繰り返し対応
   - `/general-task <タスク内容>`: general-purpose-assistantを使用して汎用タスクを実行
   - `/create-plan <タスク内容>`: task-requirement-analyzerで実装プランを作成しGitHub Issueを作成

   **自動/手動呼び出し可能スキル**:
   - `check-library`: ライブラリの情報をMCPサーバーから取得
   - `create-git-worktree`: git worktreeを利用した作業環境を自動構築
   - `create-pr`: GitHub PRを作成
   - `high-quality-commit`: 適切なgitコミット戦略でコード変更をコミット
   - `read-github-issue`: GitHub Issueの内容を取得
   - `read-unresolved-pr-comments`: GitHub PRから未対応のコメントを取得
   - `resolve-pr-comments`: GitHub PRの未解決Review threadsを一括Resolve

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
