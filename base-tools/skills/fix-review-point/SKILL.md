---
name: fix-review-point
description: Address unresolved review comments on specified branch
argument-hint: "[branch-name]"
model: sonnet
---

# Fix Review Point

Resolveしていないレビューコメントの指摘内容へ対応をするためのスキルです。
このスキルが呼び出された際には、Instructionsに従って、レビューコメントの内容を確認し、指摘内容への対応を行ってください。

# Instructions

!`git checkout $ARGUMENTS >/dev/null 2>&1`

## 実行内容

以下のステップでレビューコメントの確認とタスクの遂行を行ってください。

1. read-unresolved-pr-comments skillを用いてPRの未解決レビューコメントから修正プランを確認する
2. 実装プランから洗い出した各タスクを、base-tools:general-purpose-assistantサブエージェントを使用して実行する
  - サブエージェントの実行はタスクごとに行い、並列で実行可能なタスクがあれば並列で実行する
3. 全ての実装が完了したら、base-tools:general-purpose-assistantサブエージェントを使用してテストとLintを実行し、全て通過していることを確認する
  - 問題があれば修正を行う
4. commit-push skillを用いて、変更内容を適切にコミットし、pushする
5. resolve-pr-comments skillを用いて、すべてのレビューコメントをResolveする
6. 修正した内容を元に、PRのdescriptionを最新の状態に更新する
7. `/gemini review`というコメントをPRに追加する
