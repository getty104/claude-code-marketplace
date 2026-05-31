---
name: triage-created-issue
description: Triage a GitHub issue that already has the cc-issue-created label and is assumed to be ready to start. First inspect the comment history to decide whether human confirmation is needed (cc-need-human-check, highest priority); otherwise decide whether the issue should be closed as not needed, unanswered confirmation items remain (cc-answer-issue-questions), or it can move to execution (cc-exec-issue). Dependency checks are out of scope.
argument-hint: "[Issue number]"
hooks:
  Stop:
    - matcher: ""
      hooks:
        - type: command
          command: docker compose down --volumes --remove-orphans
---

# Triage Created Issue

着手可能と判断されたIssueに対して、確認事項の有無や実行準備の整合性を判定するトリアージスキルです。

# Instructions

## 前提

- 依存関係はすでに解決済みで、着手可能な状態である（依存関係の再確認は不要）
- まだ`cc-issue-created`ラベルがついていないIssueには `triage-issue` スキルを使用する

## 責務

1. コメント履歴の精査による人の確認要否の判断と`cc-need-human-check`ラベルの付与
2. Issue内容の精査によるクローズ判断
3. 確認事項への未回答チェックによる`cc-answer-issue-questions`ラベルの付与
4. 着手準備が整っている場合の`cc-exec-issue`ラベルの付与

## 注意事項

- Issueに付いているラベルは**絶対に外さないこと**。`gh issue edit`で`--remove-label`は使用を禁止する

## 実行ステップ

スキルが呼び出された時は、以下のステップで処理を行なってください。

### 1. Issueのdescriptionとコメント履歴の確認

対象Issueのdescription・ラベル・コメント履歴全体を取得する。

```
gh issue view $0 --json body,labels,comments
```

2つの観点で内容を読む。

- **コメント履歴全体**: 人の確認が必要なシグナル（議論の未決着、明示的な相談・承認依頼、高リスクな判断など）が含まれていないか
- **最後のコメント**: 確認事項が含まれているか、含まれている場合に未回答の項目があるか

### 2. 判定と処理

以下の優先順で判定と処理を行う。**上から順に評価し、最初に該当したパターンの処理を行ったら以降のパターンは評価しない。**

#### パターンA: 人の確認が必要と判断できる場合（最優先）

コメント履歴を精査した結果、自動でクローズ・回答・着手のいずれかを進めるよりも、人間に判断を委ねるべきと判断できる場合。

このラベルは「自動化を一旦止めて人に渡す」ためのセーフティバルブ。曖昧なまま、あるいは影響の大きい判断を自動で押し進めると手戻りや事故につながるため、確信が持てない・人間の意思決定が要るケースはここで止める。

以下のようなシグナルが該当する（例であり網羅ではない。最終的には文脈に基づいて判断する）：

- 人間同士の議論が未決着、または意見が対立したまま残っている
- 人間が明示的にレビュー・承認・相談を求めている（「要相談」「確認お願いします」「@担当者 確認して」など）
- 仕様・要件に矛盾や曖昧さがあり、コードベース調査だけでは解消できない
- 破壊的変更・セキュリティ・データ移行・課金・外部公開など、影響が大きい／不可逆な判断が絡む
- 過去に確認事項への回答を試みたが解消されず、堂々巡りになっている
- Issueのスコープを超える、優先度やビジネス判断など人間の意思決定が必要
- AI自身がクローズすべきか着手すべきか判断に確信を持てない

該当する場合、以下を実行してこのIssueの処理を終了する。**他のラベル（クローズ・`cc-answer-issue-questions`・`cc-exec-issue`）は付与しない。**

1. 人の確認が必要と判断した理由を、根拠となるコメントを引用しつつ簡潔にコメントする
   ```
   gh issue comment $0 --body "<人の確認が必要と判断した理由>"
   ```

2. `cc-need-human-check`ラベルを付与する
   ```
   gh issue edit $0 --add-label "cc-need-human-check"
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

#### パターンC: 確認事項への回答が必要な場合

最後のコメントに確認事項が存在し、かつ回答がまだ記載されていない項目がある場合：

```
gh issue edit $0 --add-label "cc-answer-issue-questions"
```

#### パターンD: 着手準備が整っている場合

確認事項がない、または全ての確認事項に回答済みである場合、実行可能と判断して`cc-exec-issue`ラベルを付与する：

```
gh issue edit $0 --add-label "cc-exec-issue"
```
