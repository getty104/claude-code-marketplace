---
name: create-pr
description: GitHubでPull Request（PR）を作成します。PRのdescriptionには指定されたテンプレートを使用し、必要な情報を記載します。PR作成後、PRのURLを報告します。
argument-hint: "[issue-number]"
model: sonnet
context: fork
---

# Create Pull Request

このスキルは、GitHubでPull Request（PR）を作成するためのスキルです。
このスキルが呼び出された際には、Instructionsに従って、PRの作成を行ってください。

> **呼び出し側への必須ルール**: 本スキルは `context: fork` のサブエージェントとして起動する場合でも、**絶対にバックグラウンド実行しないこと**。`Skill` / `Agent` ツール呼び出し時に `run_in_background: true` を指定してはならない。呼び出し元は本スキルが同期的にPRを作成しURLを返した後に、そのURLをもとに後続処理（レビュアー通知・追加ラベル付与・関連Issueリンク等）に進める設計であり、バックグラウンド化するとPR作成完了前に制御が戻ってしまい、後続処理がPR URL未取得の状態を前提に走って破綻する。他スキル（`exec-issue` / `create-epic-pr` 等）や上位エージェントから呼ぶ際もこの制約を守ること。

# Instructions

## 実行モードの制約

本スキルは `context: fork` によりサブエージェントとして起動されるが、**内部で呼び出す Bash・Skill・Agent は絶対にバックグラウンド実行しないこと**。具体的には次を守る。

- Bashツール呼び出し時に `run_in_background: true` を指定しない。既定の同期実行（フォアグラウンド）でstdoutを受け取ってから次の処理に進む
- シェルコマンド末尾に `&` を付けてバックグラウンド化しない。`nohup` / `disown` / `setsid` 等でのデタッチも禁止
- `gh pr create` は同期実行し、標準出力で返るPR URLを取得してから完了報告する。URL未取得のまま次のステップに進まないこと
- `Agent` / `Skill` ツールにも `run_in_background: true` を渡さない
- ScheduleWakeup 等で処理を後回しにすることも行わない。呼び出し元は本スキルの返却（PR URL）を同期的に待っている

**理由**: PR作成はGitHub側の状態を確定させる副作用のあるステップであり、完了前に制御が戻ると呼び出し元は「PR URL未取得の状態」で後続処理を走らせてしまい、レビュアー通知漏れ・Issueリンク欠落・重複PR作成などが発生する。同期完了とURL返却を保証することが本スキルの契約。

## PR作成ルール

PRは以下のルールで作成します。

- PRのdescriptionのテンプレートは`.github/PULL_REQUEST_TEMPLATE.md`を参照し、それに従うこと
- PRのdescriptionのテンプレート内でコメントアウトされている箇所は必ず削除すること
- PRのdescriptionには`Closes #$0`と記載すること
- `gh api user --jq '.login'`で取得したユーザーをAssigneesに追加すること
- PRのベースブランチは現在のブランチの分岐元ブランチにすること
- PRに`cc-triage-scope`ラベルを付与すること

## ベースブランチの推定

「現在のブランチの分岐元ブランチ」は、リモートトラッキングブランチ（`refs/remotes/origin/`配下）のうち、現在のブランチ自身を除き、HEADから最も近い merge-base を持つものとして推定する。Epic ブランチや任意の中間ブランチから派生した作業ブランチでも、その派生元へPRを向けられるようにするための仕組み。

```bash
CURRENT=$(git rev-parse --abbrev-ref HEAD)
git fetch origin --prune

BASE_BRANCH=$(
  git for-each-ref --format='%(refname:short)' refs/remotes/origin/ |
    grep '^origin/' | grep -v '^origin/HEAD$' |
    while read b; do
      [ "$b" = "origin/${CURRENT}" ] && continue
      mb=$(git merge-base "$b" HEAD 2>/dev/null) || continue
      [ -n "$mb" ] || continue
      dist=$(git rev-list --count "${mb}..HEAD" 2>/dev/null) || continue
      echo "$dist $b"
    done | sort -n | head -1 | awk '{print $2}' | sed 's|^origin/||'
)

# 候補が見つからない場合（孤立ブランチ等）はデフォルトブランチに fallback する
if [ -z "${BASE_BRANCH}" ]; then
  BASE_BRANCH=$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name')
fi
```

距離が同点の場合は `git for-each-ref` の列挙順（refname のアルファベット順）で先に出てきたものを採用する。期待しないブランチがベースに選ばれた場合は `--base` を明示的に指定して上書きする。

## Command Examples

```bash
gh pr create \
  --title "PRタイトル" \
  --body "$(printf 'Closes #%s\n\nPRの本文' "$0")" \
  --base "${BASE_BRANCH}" \
  --assignee "$(gh api user --jq '.login')" \
  --label "cc-triage-scope"
```
