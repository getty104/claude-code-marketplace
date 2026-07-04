---
name: create-pr
description: GitHubでPull Request（PR）を作成します。PRのdescriptionには指定されたテンプレートを使用し、必要な情報を記載します。PR作成後、PRのURLを報告します。
argument-hint: "[issue-number]"
model: sonnet
effort: high
context: fork
---

# Create Pull Request

GitHubでPull Request（PR）を作成するスキルです。呼び出された際には、Instructionsに従ってPRの作成を行ってください。

> **呼び出し側への必須ルール**: 本スキルは `context: fork` のサブエージェントとして起動する場合でも、**絶対にバックグラウンド実行しないこと**。`Agent` ツール経由で呼び出す場合は **既定が `run_in_background: true`（バックグラウンド）** のため、**必ず `run_in_background: false` を明示指定** すること。`Skill` ツール経由の場合も `run_in_background: true` を指定してはならない（既定は同期）。呼び出し元は本スキルが同期的にPRを作成しURLを返した後に後続処理（レビュアー通知・追加ラベル付与・関連Issueリンク等）に進める設計であり、バックグラウンド化するとPR URL未取得の状態を前提に後続処理が走って破綻する。他スキル（`exec-issue` / `create-epic-pr` 等）や上位エージェントから呼ぶ際もこの制約を守ること。

# Instructions

## 実行モードの制約

本スキルは `context: fork` によりサブエージェントとして起動されるが、**内部で呼び出す Bash・Skill・Agent は絶対にバックグラウンド実行しないこと**。PR作成はGitHub側の状態を確定させる副作用のあるステップであり、完了前に制御が戻ると呼び出し元がPR URL未取得のまま後続処理を走らせ、レビュアー通知漏れ・Issueリンク欠落・重複PR作成などが発生するため。同期完了とURL返却の保証が本スキルの契約。

- **`Agent` ツールは既定が `run_in_background: true`（バックグラウンド）**。呼び出しごとに **必ず `run_in_background: false` を明示指定** し、フォアグラウンドで同期的に結果を受け取ってから次の処理に進む。指定を省略した場合はバックグラウンドで走り、本スキルが未完のまま終了する
- `Bash` / `Skill` ツール呼び出し時に `run_in_background: true` を指定しない（既定は同期）。既定の同期実行でstdoutを受け取ってから次の処理に進む
- シェルコマンド末尾に `&` を付けない。`nohup` / `disown` / `setsid` でのデタッチ、`ScheduleWakeup` 等での後回しも禁止
- `gh pr create` は同期実行し、標準出力で返るPR URLを取得してから完了報告する。URL未取得のまま次のステップに進まないこと

## PR作成ルール

- PRのdescriptionのテンプレートは`.github/PULL_REQUEST_TEMPLATE.md`を参照し、それに従うこと
- テンプレート内でコメントアウトされている箇所は必ず削除すること
- PRのdescriptionには`Closes #$0`と記載すること
- `gh api user --jq '.login'`で取得したユーザーをAssigneesに追加すること
- PRのベースブランチは「ベースブランチの決定」の手順で決定したブランチにすること
- PRに`cc-triage-scope`ラベルを付与すること

## ベースブランチの決定

ベースブランチは以下の優先順で決定する。必ず 1 → 2 の順に試すこと。

1. **Epicブランチの確定的導出**: Issue `$0` が parent（Epic Issue）を持つ場合、`cc-epic-<parent番号>` をベースにする
2. **分岐元ブランチの推定（fallback）**: parentが無い場合やepicブランチがremoteに存在しない場合、merge-base距離で分岐元を推定する

### 1. Epicブランチの確定的導出

サブIssue（parentを持つIssue）の作業ブランチは `cc-epic-<parent番号>` から派生しているため、PRも同ブランチへ向ける。後述のmerge-base推定は、epicブランチ作成直後（デフォルトブランチと同一コミットを指す状態）に複数の候補ブランチが同点になり、アルファベット順のタイブレークで**誤ったepicブランチ**を選ぶことがある。そのためparentからの確定的導出を必ず先に試す。

```bash
git fetch origin --prune

BASE_BRANCH=""
PARENT=$(gh issue view "$0" --json parent --jq '.parent.number // empty' 2>/dev/null)
if [ -n "${PARENT}" ] && git rev-parse --verify --quiet "refs/remotes/origin/cc-epic-${PARENT}" >/dev/null; then
  BASE_BRANCH="cc-epic-${PARENT}"
fi
```

引数のIssue番号が渡されていない場合は本ステップをスキップし、`BASE_BRANCH` を空のままステップ2へ進む。

### 2. 分岐元ブランチの推定（fallback）

「現在のブランチの分岐元ブランチ」は、リモートトラッキングブランチ（`refs/remotes/origin/`配下）のうち、現在のブランチ自身を除き、HEADから最も近い merge-base を持つものとして推定する。Epic ブランチや任意の中間ブランチから派生した作業ブランチでも、その派生元へPRを向けられるようにするための仕組み。

```bash
if [ -z "${BASE_BRANCH}" ]; then
  CURRENT=$(git rev-parse --abbrev-ref HEAD)

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
fi

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
