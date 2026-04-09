---
name: fix-review-point
description: Address unresolved review comments on specified branch
argument-hint: "[branch-name]"
model: sonnet
effort: high
hooks:
  Stop:
    - matcher: ""
      hooks:
        - type: command
          command: docker compose down --volumes --remove-orphans
---

# Fix Review Point

Resolveしていないレビューコメントの指摘内容へ対応をするためのスキルです。
このスキルが呼び出された際には、Instructionsに従って、レビューコメントの内容を確認し、指摘内容への対応を行ってください。

# Instructions

!`git checkout $ARGUMENTS >/dev/null 2>&1`

## 実行内容

以下のステップでレビューコメントの確認とタスクの遂行を行ってください。

1. create-review-fix-plan skillを用いてPRの修正プランを確認する
2. 実装プランから洗い出した各タスクを、以下のルールに従ってサブエージェントで実行する。サブエージェントの実行はタスクごとに行い、並列で実行可能なタスクがあれば並列で実行する
  - UI実装やデザインのマークアップを行う場合: frontend-implementer サブエージェントを使用してタスクの実行を行う
  - それ以外の場合: general-purpose-assistant サブエージェントを使用してタスクの実行を行う
3. 全てのタスクが完了したら、テストとLintを実行し、全て通過していることを確認する
  - 問題があれば general-purpose-assistant サブエージェントを使用して、全てのテストとLintが通るまで修正する
4. commit-push skillを用いて、変更内容を適切にコミットし、pushする
  - Push後CIの結果は**待たずに**次のステップへ進む
5. resolve-pr-comments skillを用いて、すべてのレビューコメントをResolveする
6. 修正した内容を元に、PRのdescriptionを最新の状態に更新する

## 注意事項

- 作業は全てworktree上で行い、mainブランチで作業は絶対に行わないこと
- ファイル編集などの作業を行う際は、pwdコマンドでworktree内部であることを確認してから行うこと
  - 作業ディレクトリ: !`pwd`
