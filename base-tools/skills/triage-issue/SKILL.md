---
name: triage-issue
description: Triage a GitHub issue that does NOT yet have the cc-issue-created label. Check dependency status to decide if work can start, then add the cc-create-issue label, close the issue if it is no longer needed, or skip when dependencies are still open. Confirmation items are assumed not to exist yet.
argument-hint: "[Issue number]"
hooks:
  Stop:
    - matcher: ""
      hooks:
        - type: command
          command: docker compose down --volumes --remove-orphans
---

# Triage Issue

`cc-issue-created`ラベルがついていないIssueに対して、依存関係を確認し着手可否を判断するトリアージスキルです。

# Instructions

## 前提

- 対象Issueには`cc-issue-created`ラベルがついていない
- Issueに対する確認事項（質問とその回答）はまだ存在しない
- 確認事項の対応や、すでに`cc-issue-created`ラベルがついているIssueへの判定は `triage-created-issue` スキルを使用する

## 責務

1. 依存関係の確認による着手可否の判断と`cc-create-issue`ラベルの付与
2. Issue内容の精査によるクローズ判断

## 実行ステップ

スキルが呼び出された時は、以下のステップで処理を行なってください。

### 1. Issueの内容取得

対象Issueのdescriptionとラベルを取得する。

```
gh issue view $0 --json body,title,labels
```

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

#### パターンB: 未解決の依存関係がない場合

依存先のIssueがすべて解決済み（または依存関係がない）場合、着手可能と判断して`cc-create-issue`ラベルを付与する：

```
gh issue edit $0 --add-label "cc-create-issue"
```

#### パターンC: 未解決の依存関係がある場合

依存先にopenなIssueが1つでも存在する場合は、何もせずスキップする。
