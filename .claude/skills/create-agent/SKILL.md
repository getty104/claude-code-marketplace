---
name: create-agent
description: Create a new sub-agent definition file (agents/*.md) for the Claude Code plugin. Use this skill when the user wants to add a new specialized agent, define a new agent type, or create an agent that handles a specific domain of tasks. Trigger whenever the user mentions creating, adding, or defining a new agent or sub-agent.
argument-hint: "[agent description or purpose]"
model: opus
---

# Create Agent

引数で受け取った内容をもとに、サブエージェント定義ファイル（`agents/*.md`）を作成するスキルです。
このスキルが呼び出された際には、Instructionsに従ってエージェントの目的・役割を分析し、適切なエージェント定義を作成してください。

# Instructions

## 1. 既存エージェントの確認

まず、既存のエージェント一覧を確認し、重複や類似のエージェントがないか確認してください。

```
ls base-tools/agents/
```

既に類似の目的を持つエージェントが存在する場合は、ユーザーに報告し、新規作成か既存エージェントの更新かを確認してください。

## 2. エージェントの分析

$ARGUMENTS の内容を分析し、以下を特定してください：

- **目的**: エージェントが解決すべき課題
- **トリガー条件**: どのような状況でこのエージェントが起動されるべきか
- **必要なツール**: エージェントが使用するツール（Bash, Read, Grep, Glob, Agent, Edit, Write など）
- **モデル要件**: タスクの複雑さに応じた適切なモデル（sonnet: 高速・コスト効率重視、opus: 高品質・複雑なタスク向け）
- **メモリスコープ**: user（ユーザー固有の学習）、project（プロジェクト固有の学習）、または不要

## 3. コードベースの調査

Explore サブエージェントを使用して、エージェントが対象とするドメインに関連するコードベースの構造を調査してください。
エージェントのプロンプトに含めるべきプロジェクト固有の知識（アーキテクチャパターン、規約、ワークフロー）を把握してください。

## 4. エージェント定義ファイルの作成

以下の構造で `base-tools/agents/<agent-name>.md` ファイルを作成してください。

### ファイル構造

```markdown
---
name: <agent-name>
description: "<トリガー条件を明確に記述した説明文。Claudeがこのエージェントを自動起動する判断基準になるため、具体的なユースケースと例を含める>"
model: <sonnet|opus>
color: <cyan|blue|green|yellow|magenta|red>
memory: <user|project>（必要な場合のみ）
isolation: worktree（git操作を伴う場合のみ）
---

<エージェントのプロンプト本文>
```

### frontmatter各フィールドのガイドライン

#### name
- kebab-case（ハイフン区切り小文字）で記述
- 役割が明確にわかる名前にする

#### description
- Claudeが自動的にエージェントを起動する判断基準になる最も重要なフィールド
- 以下の構造で記述する：
  1. エージェントの用途を1文で説明
  2. 具体的なトリガー条件と使用シーン
  3. Examples（`<example>` タグを使用した具体的な使用例を2-3個）
- 各Exampleには `user`の発言、`assistant`の判断、`<commentary>` での補足を含める

#### model
- `sonnet`: 定型的な処理、パターンマッチング、高速処理が必要なタスク
- `opus`: 複雑な判断、創造的な文章生成、多段階の推論が必要なタスク

#### memory
- `user`: ユーザーの好みや作業スタイルを学習すべきエージェント
- `project`: プロジェクト固有のパターンや規約を学習すべきエージェント
- 単純な処理タスクの場合は省略可

#### isolation
- `worktree`: git操作（checkout, commit, push等）を伴うエージェントに指定
- ファイルの読み取りのみの場合は不要

### プロンプト本文のガイドライン

プロンプト本文は以下の構成で記述してください：

1. **冒頭の役割定義**: 1-2文でエージェントの専門性と責務を明示
2. **基本方針/作業プロセス**: 段階的な手順を定義（ステップ形式）
3. **品質基準**: 出力の品質を保証するためのチェックリスト
4. **出力形式**: エージェントが返す結果のフォーマット

プロンプトの記述で守るべきルール：
- 日本語で記述する
- 命令形で指示を書く（「〜してください」ではなく「〜する」形式も可）
- プロジェクト規約を織り込む（TDD、コメント禁止、型安全性など）
- ワークツリーで動作するエージェント（`isolation: worktree`）には、ワークツリー内での作業を明示する指示を含める

## 5. 確認と報告

作成したエージェント定義ファイルの内容をユーザーに報告し、以下を説明してください：

- エージェント名と役割
- トリガー条件（どのような状況で起動されるか）
- 使用モデルと理由
- メモリスコープの選択理由（設定した場合）
