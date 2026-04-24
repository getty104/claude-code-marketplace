---
name: create-pr
description: GitHubでPull Request（PR）を作成します。PRのdescriptionには指定されたテンプレートを使用し、必要な情報を記載します。PR作成後、PRのURLを報告します。
argument-hint: "[issue-number]"
context: fork
---

# Create Pull Request

このスキルは、GitHubでPull Request（PR）を作成するためのスキルです。
このスキルが呼び出された際には、Instructionsに従って、PRの作成を行ってください。

# Instructions

PRは以下のルールで作成します。

- PRのdescriptionのテンプレートは`.github/PULL_REQUEST_TEMPLATE.md`を参照し、それに従うこと
- PRのdescriptionのテンプレート内でコメントアウトされている箇所は必ず削除すること
- PRのdescriptionには`Closes #$0`と記載すること
- `gh api user --jq '.login'`で取得したユーザーをAssigneesに追加すること
- PRのベースブランチはデフォルトブランチにすること
- PRに`cc-triage-scope`ラベルを付与すること

## Command Examples

```bash
gh pr create --title "PRタイトル" --body "$(printf 'Closes #%s\n\nPRの本文' "$0")" --base "$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name')" --assignee "$(gh api user --jq '.login')" --label "cc-triage-scope"
```
