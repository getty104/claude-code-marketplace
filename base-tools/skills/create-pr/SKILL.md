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
