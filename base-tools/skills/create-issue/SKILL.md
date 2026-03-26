---
name: create-issue
description: Create an implementation plan and a GitHub Issue based on the task description provided as an argument. If an issue number is provided, update the existing issue instead.
argument-hint: "[task-description or issue-number]"
model: opus
effort: high
---

# Create Issue

引数で受け取った内容をもとに要件を整理し、GitHub Issueを作成するためのスキルです。
引数がIssue番号（数値のみ、または`#`付きの数値）の場合は、既存Issueのtitleとdescriptionを更新します。
このスキルが呼び出された際には、Instructionsに従ってタスクの内容を分析し、実装プランを作成した上でGitHub Issueを作成または更新してください。

# Instructions

## 引数の判定

`$ARGUMENTS`の内容を確認し、以下のいずれかに分岐してください：

- **Issue番号の場合**（数値のみ、または`#`付きの数値。例: `123`, `#123`）→ 「既存Issue更新フロー」へ
- **それ以外の場合**（タスク説明文）→ 「新規Issue作成フロー」へ

---

## 新規Issue作成フロー

### 1. 最新のデフォルトブランチを取得
以下のコマンドを実行して、デフォルトブランチの最新状態を取得してください。

```
git fetch
git rebase origin/$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
```

### 2. タスクの分析

タスクの内容を理解するために、以下のドキュメントを読み込んでください。

- `docs/`配下のドキュメントファイル
- `design/`配下のPencilファイル（pencil MCPツールを使用して読み込む）

これらの情報をもとに、タスクの背景・目的・関連する仕様を把握してください。

#### タスク内容

$ARGUMENTS

### 3. コードの分析

Explore サブエージェントでタスクで依頼されている要件をできるだけ詳細に分析してください。
ユーザーへの確認が必要な事項がある場合は途中で質問をせず、実装後、GitHub Issueにコメントしてください。

### 4. GitHub Issueの作成

ステップ2の分析結果をもとに、GitHub Issueを作成してください。

#### Issue作成時の注意事項

- タイトル: タスクの目的を簡潔に表現したもの
- Assignees: ghコマンドの`gh api user`で取得したユーザーをアサインしてください
- 本文: 以下の構造で作成
  - **概要**: タスクの目的と達成すべきゴール
  - **要件**: 機能要件と非機能要件のリスト
  - **参照情報**: タスクの分析で参照したドキュメントファイルのパスとデザインファイルのパス、およびそれぞれの関連箇所の説明
  - **実装プラン**: コードの分析によって策定したフェーズごとの計画
  - **影響範囲**: 変更が必要なファイルや関連コード

#### Issueの作成コマンド

`gh issue create --title "タイトル" --body "本文"`を使用してください。

### 5. GitHub Issueへ確認事項のコメントを行う
Issueの作成後、ユーザーにIssueの実施にあたり確認が必要な事項がある場合は、Issueにコメントしてください。

#### Issueへのコメントコマンド

`gh issue comment <Issue番号> --body "コメント内容"`を使用してください。

---

## 既存Issue更新フロー

### 1. 最新のデフォルトブランチを取得
以下のコマンドを実行して、デフォルトブランチの最新状態を取得してください。

```
git fetch
git rebase origin/$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
```

### 2. 既存Issueの取得

引数で受け取ったIssue番号のIssueを取得し、現在のtitleとdescriptionを確認してください。

```
gh issue view <Issue番号>
```

### 3. タスクの分析

タスクの内容を理解するために、要件定義ドキュメントやデザインファイル（Pencilファイル）を読み込んでください。
Pencilファイルはpencil MCPツールを使用して読み込むこと。

これらの情報をもとに、タスクの背景・目的・関連する仕様を把握してください。

### 4. コードの分析

Explore サブエージェントで既存Issueのtitleとdescriptionの内容に基づき、コードベースをできるだけ詳細に分析してください。
ユーザーへの確認が必要な事項がある場合は途中で質問をせず、分析後、GitHub Issueにコメントしてください。

### 5. GitHub Issueのtitleとdescriptionの更新

ステップ2で取得した既存のIssue内容とステップ3の分析結果をもとに、Issueのtitleとdescriptionを更新してください。

#### 更新時の注意事項

- タイトル: 既存のタイトルを分析結果に基づきより適切な表現に更新
- 本文: 以下の構造で作成
  - **概要**: タスクの目的と達成すべきゴール
  - **要件**: 機能要件と非機能要件のリスト
  - **参照情報**: タスクの分析で参照したドキュメントファイルのパスとデザインファイルのパス、およびそれぞれの関連箇所の説明
  - **実装プラン**: コードの分析によって策定したフェーズごとの計画
  - **影響範囲**: 変更が必要なファイルや関連コード

#### Issueの更新コマンド

`gh issue edit <Issue番号> --title "タイトル" --body "本文"`を使用してください。

### 6. GitHub Issueへ確認事項のコメントを行う
Issueの更新後、ユーザーにIssueの実施にあたり確認が必要な事項がある場合は、Issueにコメントしてください。

#### Issueへのコメントコマンド

`gh issue comment <Issue番号> --body "コメント内容"`を使用してください。

## 注意事項

- 作業はworktree上で行ってください。
- 作業中はコードの変更を行わないでください。Issueの作成・更新とコメントのみを行ってください。
