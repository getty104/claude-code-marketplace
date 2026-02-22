---
name: exec-issue
description: Execute tasks based on GitHub Issue content
argument-hint: "[issue-number]"
model: sonnet
hooks:
  Stop:
    - hooks:
        - type: command
          command: "wt_path=$(pwd) && cd ../../.. && git worktree remove "$wt_path""
---

# Execute Issue

GitHubのIssueの内容を確認し、タスクを実行する処理を行なうためのスキルです。
このスキルが呼び出された際には、Instructionsに従って、Issueの内容を確認し、タスクの遂行、PRの作成を行ってください。

# Instructions

## 実行内容

以下のステップでIssueの内容に合わせたタスクの遂行、PRの作成を行ってください。

1. read-github-issue skillを用いて、Issue番号$ARGUMENTSのIssueの内容の実装プランを確認する
2. 洗い出したタスクごとにbase-tools:general-purpose-assistantサブエージェントで実装を行う
3. 全ての実装が完了したら、base-tools:general-purpose-assistantサブエージェントでテスト・Lintが全て通過することを確認する
  - 問題があれば修正を行う
4. commit-push skillを用いて、変更内容を適切にコミットし、pushする
5. create-pr skillを用いて、変更内容を反映したPRを作成する
6. PRのURLを報告する
