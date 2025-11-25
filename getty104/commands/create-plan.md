---
allowed-tools: Bash(gh issue create *), Bash(gh issue view *), Serena(*), Context7(*)
description: Create an implementation plan using task-requirement-analyzer and create a GitHub Issue
---

引数で受け取った内容をもとに、実装プランを作成し、GitHub Issueを作成します。

## ステップ1: 実装プランの作成

task-requirement-analyzerエージェントを使用して、以下のタスク内容について実装プランを作成してください。

### タスク内容

$ARGUMENTS

## ステップ2: GitHub Issueの作成

task-requirement-analyzerエージェントが作成した実装プランをもとに、GitHub Issueを作成してください。

### Issue作成時の注意事項

- タイトル: タスクの目的を簡潔に表現したもの
- 本文: 以下の構造で作成
  - **概要**: タスクの目的と達成すべきゴール
  - **要件**: 機能要件と非機能要件のリスト
  - **実装プラン**: task-requirement-analyzerが策定したフェーズごとの計画
  - **影響範囲**: 変更が必要なファイルや関連コード
  - **確認事項**: 実装前に確認が必要な点（あれば）

### Issueの作成コマンド

`gh issue create --title "タイトル" --body "本文"`を使用してください。

## 完了条件

- 実装プランが策定されていること
- GitHub Issueが作成され、Issue番号が報告されていること
