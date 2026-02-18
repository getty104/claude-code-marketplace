---
name: update-issue
description: Update an existing GitHub Issue's description based on the issue number and request provided as arguments
argument-hint: "Issue番号: [Issue番号] 依頼内容: [依頼内容]"
model: sonnet
---

# Update Issue

引数で受け取ったIssue番号と依頼内容をもとにコードを分析し、該当のGitHub Issueのdescriptionを更新します。

# Instructions

## 実行ステップ

### 1. デフォルトブランチへの移動

デフォルトブランチに移動し、originをpullして最新状態にしてください。

### 2. 既存Issueの取得

引数で受け取ったIssue番号のIssueを取得し、現在の内容を確認してください。

```
gh issue view <Issue番号>
```

### 3. コードの分析

Explore サブエージェントで依頼内容に基づき、コードベースをできるだけ詳細に分析してください。
ユーザーへの確認が必要な事項がある場合は途中で質問をせず、実装後、GitHub Issueにコメントしてください。

#### 依頼内容
依頼内容は以下の通りです。

$ARGUMENTS

### 4. GitHub Issueの更新

ステップ2で取得した既存のIssue内容とステップ3の分析結果をもとに、Issueのdescriptionを更新してください。

#### 更新時の注意事項

- 既存のIssue構造を尊重しつつ、依頼内容を反映する
- 本文: 以下の構造で作成
  - **概要**: タスクの目的と達成すべきゴール
  - **要件**: 機能要件と非機能要件のリスト
  - **実装プラン**: コードの分析によって策定したフェーズごとの計画
  - **影響範囲**: 変更が必要なファイルや関連コード

#### Issueの更新コマンド

`gh issue edit <Issue番号> --body "本文"`を使用してください。

### 5. GitHub Issueへ確認事項のコメントを行う
Issueの更新後、ユーザーにIssueの実施にあたり確認が必要な事項がある場合は、Issueにコメントしてください。

#### Issueへのコメントコマンド

`gh issue comment <Issue番号> --body "コメント内容"`を使用してください。
