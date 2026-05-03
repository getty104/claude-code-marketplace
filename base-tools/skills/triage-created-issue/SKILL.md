---
name: triage-created-issue
description: Triage a GitHub issue that already has the cc-issue-created label and is assumed to be ready to start. Decide whether unanswered confirmation items remain (cc-answer-issue-questions), the issue should be closed as not needed, or it can move to execution (cc-exec-issue). Dependency checks are out of scope.
argument-hint: "[Issue number]"
hooks:
  Stop:
    - matcher: ""
      hooks:
        - type: command
          command: docker compose down --volumes --remove-orphans
---

# Triage Created Issue

`cc-issue-created`ラベルがついており、すでに着手可能と判断されたIssueに対して、確認事項の有無や実行準備の整合性を判定するトリアージスキルです。

# Instructions

## 前提

- 対象Issueには`cc-issue-created`ラベルがついている
- 依存関係はすでに解決済みで、着手可能な状態である（依存関係の再確認は不要）
- まだ`cc-issue-created`ラベルがついていないIssueには `triage-issue` スキルを使用する

## 責務

1. 確認事項への未回答チェックによる`cc-answer-issue-questions`ラベルの付与
2. 着手準備が整っている場合の`cc-exec-issue`ラベルの付与
3. Issue内容の精査によるクローズ判断

## 注意事項

- Issueに付いているラベルは**絶対に外さないこと**。`gh issue edit`で`--remove-label`は使用を禁止する

## 実行ステップ

スキルが呼び出された時は、以下のステップで処理を行なってください。

### 1. Issueのdescriptionと最後のコメントの確認

対象Issueのdescriptionと最後のコメントを取得する。

```
gh issue view $0 --json body,comments --jq '{body: .body, lastComment: .comments[-1]}'
```

最後のコメントに確認事項が含まれているか、含まれている場合に未回答の項目があるかを確認する。

### 2. 判定と処理

以下の優先順で判定と処理を行う。

#### パターンA: Issueの内容が対応不要と判断できる場合

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

#### パターンB: 確認事項への回答が必要な場合

最後のコメントに確認事項が存在し、かつ回答がまだ記載されていない項目がある場合：

```
gh issue edit $0 --add-label "cc-answer-issue-questions"
```

#### パターンC: 着手準備が整っている場合

確認事項がない、または全ての確認事項に回答済みである場合、実行可能と判断して`cc-exec-issue`ラベルを付与する：

```
gh issue edit $0 --add-label "cc-exec-issue"
```
