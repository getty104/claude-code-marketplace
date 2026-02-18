---
name: create-issue
description: Create an implementation plan and a GitHub Issue based on the task description provided as an argument
argument-hint: "[task-description]"
model: sonnet
---

# Create Issue

引数で受け取った内容をもとに要件を整理し、GitHub Issueを作成します。

# Instructions

## 実行ステップ

### 1. デフォルトブランチへの移動

デフォルトブランチに移動し、originをpullして最新状態にしてください。

### 2. コードの分析

Explore サブエージェントでタスクで依頼されている要件をできるだけ詳細に分析してください。
ユーザーへの確認が必要な事項がある場合は途中で質問をせず、実装後、GitHub Issueにコメントしてください。

#### タスク内容

$ARGUMENTS

### 3. GitHub Issueの作成

ステップ2の分析結果をもとに、GitHub Issueを作成してください。

#### Issue作成時の注意事項

- タイトル: タスクの目的を簡潔に表現したもの
- Assignees: ghコマンドの`gh api user`で取得したユーザーをアサインしてください
- 本文: 以下の構造で作成
  - **概要**: タスクの目的と達成すべきゴール
  - **要件**: 機能要件と非機能要件のリスト
  - **実装プラン**: コードの分析によって策定したフェーズごとの計画
  - **影響範囲**: 変更が必要なファイルや関連コード

#### Issueの作成コマンド

`gh issue create --title "タイトル" --body "本文"`を使用してください。

### 4. GitHub Issueへ確認事項のコメントを行う
Issueの作成後、ユーザーにIssueの実施にあたり確認が必要な事項がある場合は、Issueにコメントしてください。

#### Issueへのコメントコマンド

`gh issue comment <Issue番号> --body "コメント内容"`を使用してください。
