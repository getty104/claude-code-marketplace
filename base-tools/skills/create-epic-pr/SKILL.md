---
name: create-epic-pr
description: "Create an aggregated Epic PR from a `cc-epic-<Issue number>` branch to the default branch. Takes the Epic Issue number as argument, assumes sub-PRs have already been merged into the epic branch, and automatically generates the PR title and description from the commit log against the base branch (including sub-PR / sub-Issue references). The PR is posted via `gh pr create` with no label and `Closes #<Epic Issue>`."
argument-hint: "[issue-number]"
disable-model-invocation: true
---

# Create Epic Pull Request

引数として渡された Epic Issue 番号 `$0` に対応する `cc-epic-$0` ブランチから、デフォルトブランチへの集約PR（Epic PR）を作成するスキルです。

epic ブランチは、複数のサブIssueの実装PRをまとめてマージする集約用ブランチ。本スキルが呼ばれる時点でサブPRはすべて epic ブランチへマージ済みであることが前提（本スキルは epic ブランチも個別コミットも作らない）。ベースブランチとの差分コミットログを元にPR descriptionを自動生成し、`gh pr create` で投稿する。

ユーザーへの確認は行わず、判断はすべて本スキル内のルールに従って自動で決定する。中断条件に該当した場合のみ、理由を出力して終了する。

# Instructions

## 実行モードの制約: サブエージェント・サブスキル・Bashをバックグラウンド実行しないこと

本スキルは `claude-task-worker` の `epic-issue` ワーカー（`cc-epic-issue` ラベル）から自動起動される想定である。ワーカーはスキルプロセスの同期完了を根拠にラベル遷移や後続処理を進めるため、**本スキル内部で呼び出す `Agent` / `Skill` / `Bash` を絶対にバックグラウンド実行しないこと**。具体的には次を守る。

- `Agent` / `Skill` ツール呼び出し時に `run_in_background: true` を指定しない。既定の同期実行（フォアグラウンド）で最終出力を受け取ってから次の処理に進む
- 同一メッセージ内で複数の `Agent` / `Skill` を並列に投げるのは「並列実行」であって「バックグラウンド実行」ではないため許容される（各サブエージェントの完了はその場で同期的に待つ）
- `Bash` ツール呼び出し時にも `run_in_background: true` を指定しない。特に `gh pr create` は同期実行し、標準出力で返るPR URLを取得してから完了報告する必要がある。シェルコマンド末尾に `&` を付けたり、`nohup` / `disown` / `setsid` などでプロセスをデタッチしたりしない
- `ScheduleWakeup` などで処理を後回しにすることも行わない

**理由**: バックグラウンド化するとサブエージェント/子プロセスの完了前に本スキルが終了してしまい、`claude-task-worker` は「Epic PR 作成が完了した」と誤認して次のラベル遷移や別ワーカー起動に進んでしまう。結果として、PR URL 未取得のまま報告されたり、Epic PR が未作成の状態で `cc-epic-issue` が外されてしまう、といった状態壊れが発生する。ワーカー連携の同期性を担保するため、本スキルの内部処理はすべて同期実行で完結させる必要がある。

## フェーズ0: 引数判定と事前チェック

### 0-1. 引数の妥当性確認

`$0` が数値のみのIssue番号であること（例: `123`）を確認する。

引数が空、または数値以外を含む場合は中断する。以降、`$0` をそのままIssue番号として扱う。

### 0-2. Epic Issueの存在確認

```bash
gh issue view $0 --json number,title,state,url
```

Issueが存在しない、または `state` が `CLOSED` の場合は中断する。`title` は後続のPRタイトル生成、`url` は最終報告で使うため保持する。

### 0-3. 作業ディレクトリと未コミット変更の確認

`pwd` でカレントを確認する。`git status --short` で未コミット変更を確認し、変更があれば中断する。本スキルはコードを編集しないので、未コミット変更はユーザーの作業中ファイルである可能性が高く、退避操作も行わない。

### 0-4. デフォルトブランチ名の取得

```bash
gh repo view --json defaultBranchRef -q .defaultBranchRef.name
```

失敗した場合は中断する。取得した値を `<BASE>` と呼ぶ。

**完了条件**: `$0` / Epic Issueタイトル / `<BASE>` が確定し、未コミット変更が無いこと。

---

## フェーズ1: epicブランチへのチェックアウト

### 1-1. リモートからの最新取得

```bash
git fetch origin --prune
```

### 1-2. ブランチの特定とチェックアウト

対象ブランチ名は `cc-epic-$0`。以下の優先順で処理する:

1. リモートに存在する場合（`git rev-parse --verify origin/cc-epic-$0` が成功）:
   - `git checkout cc-epic-$0` でチェックアウト（ローカルに無ければ自動で tracking branch が作られる）
   - `git pull --ff-only origin cc-epic-$0` で最新化する。ff-only 失敗時は中断
2. ローカルのみに存在する場合（リモートに無く、`git rev-parse --verify cc-epic-$0` が成功）:
   - `git checkout cc-epic-$0` でチェックアウト
3. どちらにも存在しない場合は中断する。サブPRマージ前の早すぎる呼び出しを防ぐため、ブランチが無いケースでは自動作成せずに止める。

**完了条件**: `git rev-parse --abbrev-ref HEAD` が `cc-epic-$0` を返すこと。

`git pull` は ff-only でのみ実行する。マージコンフリクトが発生した場合は手動解決を促す。

---

## フェーズ2: ベースブランチとの差分ログ取得

### 2-1. merge-base から HEAD までのコミット一覧

```bash
BASE_REF=$(git merge-base origin/<BASE> HEAD)
git log ${BASE_REF}..HEAD --pretty=format:'%h%x09%s'
```

差分コミットが0件の場合は中断する（PR にする変更がない）。

### 2-2. サブPR / サブIssue 番号の抽出

各コミットメッセージから以下のパターンで PR / Issue 番号を抽出する:

- `Merge pull request #<番号>` パターン → サブPR
- `(#<番号>)` パターン（squash merge の慣習）→ サブPR
- `Closes #<番号>` / `closes #<番号>` / `Closed #<番号>` パターン → サブIssue
- `Fixes #<番号>` / `fixes #<番号>` / `Resolves #<番号>` パターン → サブIssue

`$0` 自身は除外し、重複も除去する。順序はコミットログ順を維持する。

**完了条件**: 差分コミット一覧と、サブPR / サブIssue 番号の抽出結果が得られていること。

---

## フェーズ3: PR 本文の生成

### 3-1. PR タイトル

`Epic: <Epic Issueタイトル>` 形式とする。

### 3-2. PR 本文の組み立て

以下のフォーマットで本文を組み立てる。サブPR / サブIssue が無いセクションは省略せず「なし」と1行だけ書く。後続レビューが「未記入」と「該当なし」を区別できなくなるため、空のままにしない。

```markdown
## 概要
Epic Issue #$0「<Epic Issueタイトル>」に紐づくサブタスクをまとめた集約PRです。

## 含まれる変更
- `<short hash>` <subject>
- `<short hash>` <subject>
...

## 含まれるサブPR
- #<番号>
- #<番号>
（なければ "なし"）

## 含まれるサブIssue
- #<番号>
- #<番号>
（なければ "なし"）

Closes #$0
```

`Closes #$0` を必ず含めることで、Epic PR がマージされたとき Epic Issue も自動で close する。

---

## フェーズ4: PR の作成（`gh pr create` 実行）

### 4-1. assignee の取得

```bash
ME=$(gh api user --jq '.login')
```

### 4-2. `gh pr create` の実行

本文渡しは `--body-file -` + heredoc（`<<'EOF'` クォート版）を使う。`--body "..."` 形式は本文中のバッククォート・`$`・改行でエスケープが頻繁に壊れるため使わない。

heredoc は `<<'EOF'` でクォートしてシェル展開を抑止するため、本文中の `$0` などのプレースホルダは heredoc に渡す前に実値へ置換しておくこと。

```bash
gh pr create \
  --title "Epic: <Epic Issueタイトル>" \
  --base "<BASE>" \
  --assignee "${ME}" \
  --body-file - <<'EOF'
## 概要
Epic Issue #$0「<Epic Issueタイトル>」に紐づくサブタスクをまとめた集約PRです。

## 含まれる変更
- `<short hash>` <subject>
...

## 含まれるサブPR
- #<番号>
...

## 含まれるサブIssue
- #<番号>
...

Closes #$0
EOF
```

ラベルは付与しない（`--label` フラグを使わない）。

`gh pr create` が失敗した場合は失敗ログを最終報告に含めて終了する。再試行は1回までとする。

---

## フェーズ5: 最終報告

`gh pr create` が返した PR URL と、以下を1-3行で報告して終了する:

- ブランチ名（`cc-epic-$0`）
- 差分コミット数
- 含まれたサブPR / サブIssue の件数

---

## 中断条件

以下のいずれかに該当する場合のみ、理由を1-2行で出力して即中断する。

- 引数が空、または Issue 番号として解釈できない
- `gh issue view` で Issue が見つからない、または `CLOSED`
- 未コミット変更が存在する
- デフォルトブランチ名の取得失敗
- `cc-epic-$0` ブランチがローカル / リモートのいずれにも存在しない
- `git pull --ff-only` が ff-only で失敗（ローカルとリモートの乖離）
- ベースブランチとの差分コミットが0件
- `gh pr create` が失敗し、再試行しても解消しない
