---
name: create-issue
description: Create an implementation plan using task-requirement-analyzer and create a GitHub Issue
argument-hint: "[task-description]"
model: opus
---

# Create Issue

引数で受け取った内容をもとに要件を整理し、GitHub Issueを作成します。

# Instructions

## 実行ステップ

### 1. デフォルトブランチへの移動

デフォルトブランチに移動し、originをpullして最新状態にしてください。

### 2. コードの分析

Explore サブエージェントでタスクで依頼されている要件をできるだけ詳細に分析してください。
また、要件を整理する上で判断が難しい場合は、適宜質問を行い、必要な情報を収集してください。

#### タスク内容

$ARGUMENTS

### 3. GitHub Issueの作成

ステップ2の分析結果をもとに、GitHub Issueを作成してください。

#### Issue作成時の注意事項

- タイトル: タスクの目的を簡潔に表現したもの
- 本文: 以下の構造で作成
  - **概要**: タスクの目的と達成すべきゴール
  - **要件**: 機能要件と非機能要件のリスト
  - **実装プラン**: Planサブエージェントが策定したフェーズごとの計画
  - **影響範囲**: 変更が必要なファイルや関連コード
  - **確認事項**: 実装前に確認が必要な点（あれば）

### 4. 実装プランの改善

- 以下の処理を繰り返してください
   - ユーザーにGitHub Issueの内容が適切か確認してください
   - ユーザーからフィードバックがあった場合、GitHub Issueの内容を改善してください
   - ユーザーからの承認が得られたら、処理を終了してください

#### Issueの作成コマンド

`gh issue create --title "タイトル" --body "本文"`を使用してください。
