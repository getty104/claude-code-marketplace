---
name: triage-issue
description: Triage GitHub issue assigned to the user. Categorize and process issues by adding appropriate labels (cc-create-issue, cc-exec-issue, or cc-update-issue) based on dependency analysis, issue detail status, and whether confirmation items need answers.
argument-hint: "[Issue number]"
model: sonnet
effort: high
hooks:
  Stop:
    - matcher: ""
      hooks:
        - type: command
          command: docker compose down --volumes --remove-orphans
---

# Triage Issues

対象のIssueに適切なラベルを付与するトリアージスキルです。

# Instructions

## 実行ステップ

スキルが呼び出された時は、以下のステップで処理を行なってください。

### 1. Issueのdescriptionと最後のコメントの確認

対象Issueのdescriptionと最後のコメントを取得する。

```
gh issue view $0 --json body,comments --jq '{body: .body, lastComment: .comments[-1]}'
```

最後のコメントに確認事項が含まれているか確認する。

### 2. 判定と処理

以下の優先順で判定と処理を行う。

#### パターンA: 確認事項への回答が必要な場合

最後のコメントに確認事項が存在し、かつ回答がまだ記載されていない項目がある場合：

```
gh issue edit $0 --add-label "cc-answer-questions"
```

#### パターンB: Issueの内容が対応不要と判断できる場合

Issueの内容を精査した結果、以下のいずれかに該当する場合：

- すでに別のIssueやPRで対応済み・重複している
- 要件や仕様の変更により不要になった
- 誤って起票されたIssueである
- その他、明らかに対応不要と判断できる

以下を実行する：

1. Issueにクローズ理由をコメントで記載する
   ```
   gh issue comment $0 --body "<クローズ理由の説明>"
   ```

2. Issueをcloseする
   ```
   gh issue close $0
   ```

#### パターンC: 未解決の依存関係がなく、cc-issue-createdラベルがついていない場合

依存関係が全て解決済みで、Issueに`cc-issue-created`ラベルがついていない場合：

```
gh issue edit $0 --add-label "cc-create-issue"
```

#### パターンD: 未解決の依存関係がなく、cc-issue-createdラベルがついている場合

依存関係が全て解決済みで、Issueに`cc-issue-created`ラベルがついている場合：

```
gh issue edit $0 --add-label "cc-exec-issue"
```

#### パターンE: 未解決の依存関係がある場合

依存先にopenなIssueが1つでも存在する場合は、何もせずスキップする。
