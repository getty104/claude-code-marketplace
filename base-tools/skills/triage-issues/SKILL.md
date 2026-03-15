---
name: triage-issues
description: Triage GitHub issues assigned to the user. Categorize and process issues by adding appropriate labels (cc-create-issue, cc-exec-issue, or cc-update-issue) based on dependency analysis, issue detail status, and whether confirmation items need answers.
argument-hint: ""
model: opus
---

# Triage Issues

ユーザーにアサインされたIssueを取得し、各Issueの状態に応じて適切なラベルを付与するトリアージスキルです。

# Instructions

## 実行ステップ

### 1. ユーザー情報の取得

```
gh api user --jq '.login'
```

### 2. ユーザーにアサインされたIssueの一覧取得

ユーザーにアサインされているIssueを取得してください。

```
gh issue list --assignee <ユーザー名> --json number,title,labels,body --limit 100
```

### 3. 未完了Issueの取得

依存関係の判定に使用するため、現在openな全Issueを取得してください。

```
gh issue list --state open --json number,title,labels,body --limit 200
```

### 4. 依存関係グラフの構築

ステップ2・3で取得した全Issueについて、各Issueの本文中に含まれるIssue参照（`#<Issue番号>`やIssueのURL）を抽出し、依存関係グラフを構築してください。

依存関係の判定ルール:
- Issueの本文中に他のIssueへの参照（`#<Issue番号>`やIssueのURL）が含まれている場合、そのIssueに依存しているとみなす
- 依存先Issueがopenである場合、その依存関係は**未解決**とする
- 依存先Issueがclosedである場合、その依存関係は**解決済み**とする（依存関係なしと同等に扱う）

依存関係のトラバース:
- 直接の依存先だけでなく、依存先の依存先も再帰的にたどる
- Issue Aが Issue Bに依存し、Issue BがIssue Cに依存している場合、Issue Cがopenであれば Issue Aも依存待ち状態とする
- 循環依存が検出された場合は、循環に含まれる全Issueを依存待ちとして報告する

### 5. 各Issueのトリアージ

ステップ2で取得したIssueのうち、`cc-in-progress`ラベルが**ついていない**ものに対して、以下の判定を行ってください。

#### 5a. 最後のコメントの確認

各Issueの最後のコメントを取得してください。

```
gh issue view <Issue番号> --json comments --jq '.comments[-1]'
```

最後のコメントに確認事項が含まれているか確認してください。

#### 5b. 判定と処理

以下の優先順で判定してください。

##### **パターンA: 確認事項への回答が必要な場合**

最後のコメントに確認事項が存在し、かつ回答がまだ記載されていない項目がある場合：

1. 最後のコメントを編集し、各確認事項ごとに investigation-responder サブエージェントを用いて回答を追記する
  - 回答が必要な確認事項が複数ある場合は、全ての項目に対して回答を追記する
2. `cc-update-issue`ラベルを付与する

回答項目の追記イメージ

```
## 回答

### 確認事項1
（回答内容）

### 確認事項2
（回答内容）

...（未回答の確認事項があれば同様に追加）
```

コメントの編集には以下のコマンドを使用してください。コメントIDは`gh issue view`の結果から取得できます。

```
gh api repos/{owner}/{repo}/issues/comments/<コメントID> -X PATCH -f body="<編集後のコメント全文>"
```

ラベルの付与:
```
gh issue edit <Issue番号> --add-label "cc-update-issue"
```

##### **パターンB: 未解決の依存関係がなく、cc-created-issueラベルがついていない場合**

ステップ4で構築した依存関係グラフにおいて、再帰的にたどった全ての依存先Issueがclosedであるか依存先が存在せず、かつIssueに`cc-created-issue`ラベルがついていない場合：

1. `cc-create-issue`ラベルを付与する

```
gh issue edit <Issue番号> --add-label "cc-create-issue"
```

**パターンC: 未解決の依存関係がなく、cc-created-issueラベルがついている場合**

ステップ4で構築した依存関係グラフにおいて、再帰的にたどった全ての依存先Issueがclosedであるか依存先が存在せず、かつIssueに`cc-created-issue`ラベルがついている場合：

1. `cc-exec-issue`ラベルを付与する

```
gh issue edit <Issue番号> --add-label "cc-exec-issue"
```

**パターンD: 未解決の依存関係がある場合**

ステップ4で構築した依存関係グラフにおいて、再帰的にたどった依存先にopenなIssueが1つでも存在する場合は、何もせずスキップしてください。

### 6. 結果の報告

処理結果を以下の形式で報告してください。

- 処理したIssueの総数
- パターンA（確認事項への回答が必要）: Issue番号の一覧
- パターンB（Issue詳細の作成が必要）: Issue番号の一覧
- パターンC（実行可能）: Issue番号の一覧
- パターンD（依存待ち）: Issue番号の一覧と依存チェーン（例: #10 → #5 → #3）
