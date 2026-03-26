---
name: exec-issue
description: Execute tasks based on GitHub Issue content
argument-hint: "[issue-number] [--triage-scope]"
model: opus
hooks:
  Stop:
    - matcher: ""
      hooks:
        - type: command
          command: docker compose down
---

# Execute Issue

GitHubのIssueの内容を確認し、タスクを実行する処理を行なうためのスキルです。
このスキルが呼び出された際には、Instructionsに従って、Issueの内容を確認し、タスクの遂行、PRの作成を行ってください。

# Instructions

## 実行内容

以下のステップでIssueの内容に合わせたタスクの遂行、PRの作成を行ってください。

1. read-github-issue skillを用いて、Issue番号`$0`のIssueの内容の実装プランを確認する
2. 実装プランから洗い出した各タスクを、base-tools:general-purpose-assistant サブエージェントを使用して実行する
  - サブエージェントの実行はタスクごとに行い、並列で実行可能なタスクがあれば並列で実行する
3. 全ての実装が完了したら、base-tools:general-purpose-assistant サブエージェントを使用してテストとLintを実行し、全て通過していることを確認する
  - 問題があればbase-tools:general-purpose-assistant サブエージェントを使用して修正を行う
4. `git status`でコード変更の有無を確認する
   - コード変更がない場合は、Issue `$0` に「調査の結果、コード変更は不要と判断しました」旨のコメントを`gh issue comment`で追加し、`gh issue close`でIssueをクローズして処理を終了する
   - コード変更がある場合は、以降のステップに進む
5. commit-push skillを用いて、変更内容を適切にコミットし、pushする
6. create-pr skillを用いて、変更内容を反映したPRを作成する
   - 第二引数の値: `$1` が`--triage-scope`の場合は、作成したPRに`cc-triage-scope`ラベルを付与する
7. PRのURLを報告する

## 注意事項

- 作業は全てworktree上で行い、mainブランチで作業は絶対に行わないこと
- ファイル編集などの作業を行う際は、pwdコマンドでworktree内部であることを確認してから行うこと
