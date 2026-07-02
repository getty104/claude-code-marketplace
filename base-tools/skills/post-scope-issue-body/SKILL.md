---
name: post-scope-issue-body
description: "INTERNAL/HELPER skill — do NOT invoke directly from a user query. This is the shared formatter/poster used by answer-issue-questions and breakdown-issues. It formats a scope GitHub Issue body (label cc-triage-scope, used before code analysis), runs the pre-posting checklist, and executes `gh issue create`. Invoke this skill ONLY from one of the parent skills via the Skill tool, after the parent has finalized the task breakdown. If a user asks to 'create a scope issue' or similar, route them to the appropriate parent skill (/breakdown-issues for fresh breakdowns, /answer-issue-questions for derived sub-tasks) rather than invoking this one directly."
user-invocable: false
context: fork
model: sonnet
effort: high
argument-hint: "<YAML input — see SKILL.md>"
---

# Post Scope Issue Body

呼び出し元スキル（`answer-issue-questions` / `breakdown-issues`）から委譲され、スコープIssue本文の整形と投稿を担う共有スキル。親スキルのタスク分解結果を受け取り、以下を一括実行する。

1. 「スコープIssue」の正規フォーマットに整形
2. 投稿前チェックの実施
3. `gh issue create` の実行

ユーザーから直接呼び出される想定ではない（親スキル内のステップから Skill tool 経由で起動される）。直接呼ばれ、入力 YAML が args に無い場合は、親スキル（breakdown-issues / answer-issue-questions）の使用を促して終了する。

**親Project紐付けや複数Issueの作成順序・依存関係Issue番号の確定は呼び出し側の責務**。本スキルは1回の呼び出しで1つのIssueを作成して URL を返すのみ。複数作成したい場合は呼び出し側がループする。

> **呼び出し側への必須ルール**: 本スキルを**絶対にバックグラウンド実行しないこと**。`Agent` ツール経由で呼び出す場合は **既定が `run_in_background: true`（バックグラウンド）** のため、**必ず `run_in_background: false` を明示指定** すること。`Skill` ツール経由の場合も `run_in_background: true` を指定してはならない（既定は同期）。呼び出し元（`answer-issue-questions` / `breakdown-issues` — いずれも `claude-task-worker` から自動起動される可能性がある）は、本スキルが同期的に `gh issue create` を完了し Issue URL を返したことを確認してから次のIssue作成ループや後続ラベル遷移に進む設計であり、バックグラウンド化すると依存関係Issue番号が確定しないまま次のIssue作成に突入して破綻する。

# Instructions

## 実行モードの制約: サブエージェント・サブスキル・Bashをバックグラウンド実行しないこと

本スキルは `context: fork` のサブエージェントとして起動されるが、**内部で呼び出す `Bash` / `Skill` / `Agent` も絶対にバックグラウンド実行しない**。

- `Bash` に `run_in_background: true` を指定しない。特に `gh issue create` は同期実行し、返却された Issue URL を確認してから完了報告する
- コマンド末尾に `&` を付けたり、`nohup` / `disown` / `setsid` でデタッチしたりしない
- **`Agent` ツールは既定が `run_in_background: true`（バックグラウンド）**。呼び出しごとに **必ず `run_in_background: false` を明示指定** し、フォアグラウンドで同期的に結果を受け取ってから次の処理に進む。指定を省略した場合はバックグラウンドで走り、本スキルが未完のまま終了する
- `Skill` にも `run_in_background: true` を渡さない（既定は同期）
- `ScheduleWakeup` などで処理を後回しにしない

**理由**: 本スキルは「作成された Issue の URL」を同期返却する契約であり、バックグラウンド化すると呼び出し元が依存関係 Issue 番号を確定できないまま次のスコープ Issue 作成に進み、Issue の依存グラフが壊れて `claude-task-worker` の `create-issue` ワーカーが正しい順序で処理できなくなる。

## 入力（args 経由の YAML ブロック）

### 呼び出し規約

呼び出し元の親スキル（`answer-issue-questions` / `breakdown-issues`）は、**本スキル起動時の `args` に以下の YAML ブロックを文字列として渡す**こと。本スキルは `$ARGUMENTS` を YAML として機械的にパースして入力として扱う。

```yaml
mode: create  # 現状 create のみサポート
title: <Issueタイトル>
sections:
  概要: |
    （1-3行の概要）
  要件: |
    - 要件1
    - 要件2
  参照情報: |
    - ドキュメント: `<path>` — <説明>
    （無ければ "なし"）
  優先度: High  # High / Medium / Low のいずれか
  見積もり規模: M  # S / M / L / XL のいずれか
# 以下は GitHub ネイティブ relationships 用のオプション項目。
# 不要なら省略する（空配列や null を入れない＝そのまま書かない）。
parent: <親Issueの番号>           # 省略可。指定時は --parent で sub-issue として作成される
blocked_by: [<Issue番号>, ...]   # 省略可。指定時は --blocked-by で blocked-by relationship が貼られる
blocking: [<Issue番号>, ...]     # 省略可。指定時は --blocking で blocking relationship が貼られる
```

args に渡す YAML は上記の通り**トップレベルから直接書く**（ラッパキーなし）。

### args の渡し方

`Skill(skill='post-scope-issue-body', args=<上記YAML文字列>)` の形で起動する。args は改行を含む複数行文字列として渡せる。

### 取り扱い規約

- 空セクションを省略しない。「なし」で埋める（後続スキルが「未記入」と区別できなくなるため）。
- `parent` / `blocked_by` / `blocking` の Issue 番号は**呼び出し側で確定済みのもの**が前提。本スキルは渡された値をそのまま `gh issue create` のオプションに渡す。先行Issueの番号確定を待つ順序制御は呼び出し側の責務。
- args の YAML が壊れていたり項目が欠けている場合は、`mode` 以外であれば最低限の推定で埋める（例: 優先度・見積もり規模が空なら `Medium` / `M`）。`mode` だけは推定不可なので欠けていたら中断する。
- args が空、もしくは YAML として解釈できない場合（直接ユーザー起動など）は、親スキル（`breakdown-issues` / `answer-issue-questions`）の使用を促して中断する。

## Issueフォーマット（厳守）

このスキルが投稿するのは「コード分析前のスコープIssue」（ラベル `cc-triage-scope`）であり、本文は必ず以下の正規フォーマットに従う。後続の Issue ライフサイクルスキルは本文を読んでラベリング・タスク分解を行うため、セクションの過不足・順序の入れ替え・見出し名のゆらぎは後続スキルの判断と人のレビュー可読性を損なう。独自のアレンジは加えない。

依存関係は GitHub の relationships（blocked-by / blocking）と sub-issue 関係でネイティブに表現する方針のため、本文側に `## 依存関係` セクションは持たず、`gh issue create` の `--parent` / `--blocked-by` / `--blocking` オプションで貼る（GitHub UI で関係性が表示されるため本文での重複記述は不要、かつ二重管理によるズレを避けられる）。

### 本文テンプレート

```markdown
## 概要
（このタスクが達成すべきゴールを1-3行で記述）

## 要件
- （機能要件・非機能要件を箇条書き。1項目1行）

## 参照情報
- ドキュメント: `<path>` — <関連箇所の説明>
- デザイン: `<path>` — <関連箇所の説明>
（該当する参照情報がなければ `- なし` の1行だけ書く）

## 優先度
High / Medium / Low のいずれか1つ

## 見積もり規模
S / M / L / XL のいずれか1つ
```

### 投稿前チェック（`gh issue create` 実行の直前に必ず確認）

本文を `gh` に渡す直前に以下を確認し、1つでも満たさない場合は本文を直してから実行する。

- 見出しが `## 概要` → `## 要件` → `## 参照情報` → `## 優先度` → `## 見積もり規模` の順で、過不足なく並んでいる
- テンプレート外の見出しを追加していない（特に `## 依存関係` は GitHub relationships に移行済みなので本文に書かない）
- 優先度・見積もり規模は規定の選択肢から1つだけ選んでいる
- 空になるセクションを省略せず「なし」で埋めている

## 実行ステップ

### 1. args の YAML パース

`$ARGUMENTS` を YAML として解釈し、`mode` / `title` / `sections` / `parent` / `blocked_by` / `blocking` を取り出す。`mode` が読み取れない、もしくは args が空ならば中断条件に従って終了する。

### 2. 本文の組み立てと投稿前チェック

「本文テンプレート」に従って本文を組み立て、必ず「投稿前チェック」の項目を1つずつ確認する。1つでも満たさない場合は本文を直してから次へ進む。

### 3. `gh issue create` で投稿

**`--body "..."` 形式は使わない**。本文中のバッククォート・`$`・`!`・改行でエスケープが頻繁に壊れるため、必ず `--body-file -` + heredoc（`<<'EOF'` でクォート、シェル展開を抑止）を使う。

YAML 入力に `parent` / `blocked_by` / `blocking` が含まれていれば、それぞれ `--parent <番号>` / `--blocked-by <番号,番号,...>` / `--blocking <番号,番号,...>` としてフラグに追加する。値が無い項目はフラグごと省略する（空文字列を渡すと `gh` が引数エラーで落ちるため、配列が空 / null の場合は組み立て時点で除外する）。`--blocked-by` / `--blocking` はカンマ区切りで複数番号を1つのフラグにまとめる。

```bash
ME=$(gh api user --jq '.login')

# YAML 入力から組み立てた追加フラグを EXTRA_FLAGS 配列に詰める。
# 例: parent=42, blocked_by=[10,11] のとき EXTRA_FLAGS=(--parent 42 --blocked-by 10,11)
# 値が無い項目は何も push しない。
EXTRA_FLAGS=()
# [parent があるとき]     EXTRA_FLAGS+=(--parent "$PARENT_NUMBER")
# [blocked_by があるとき] EXTRA_FLAGS+=(--blocked-by "$(IFS=,; echo "${BLOCKED_BY[*]}")")
# [blocking があるとき]   EXTRA_FLAGS+=(--blocking "$(IFS=,; echo "${BLOCKING[*]}")")

NEW_ISSUE_URL=$(gh issue create \
  --title "<タイトル>" \
  --assignee "$ME" \
  --label "cc-triage-scope" \
  "${EXTRA_FLAGS[@]}" \
  --body-file - <<'EOF'
## 概要
...

## 要件
- ...

## 参照情報
- ...

## 優先度
...

## 見積もり規模
...
EOF
)
```

成功時、コマンドが標準出力に返す Issue URL を保持する。

`--parent` / `--blocked-by` / `--blocking` の検証エラー（存在しない Issue 番号、権限不足、`gh` バージョン未達 等）は `gh issue create` 自体を失敗させ、その場合 Issue も作成されない（「relationship が貼れないなら作るな」という fail-fast の意図的な挙動）。失敗を呼び出し元に伝えて中断する（後追いの best-effort リンクが必要な場合は、呼び出し元側で `parent` を渡さず作成し、別途 `gh issue edit --add-sub-issue` 等でリンクするフローを使うこと。例: `answer-issue-questions`）。

### 4. 呼び出し元への返却

以下を出力して、呼び出し元の親スキルが「最終報告」「親Project紐付け」「次のIssue作成」で使えるようにする。親Project紐付けや複数Issue作成のループは本スキルの責務外で、呼び出し側が URL/番号を受け取って続きを処理する。

- 作成された Issue の URL
- 作成された Issue の番号（後続Issueの `blocked_by` 入力に使える）

## 中断条件

以下のいずれかに該当する場合のみ、理由を1-2行で出力して**即中断**する。

- `mode` が `create` 以外（現状 edit はサポートしない）
- args が空、もしくは YAML として解釈できない
- `gh issue create` が失敗し、再試行しても解消しない

## 注意事項

- 本スキルは**コードを一切変更しない**。Issue の作成のみを行う
- `gh issue create` の本文渡しは**必ず `--body-file -` + heredoc**（`<<'EOF' ... EOF`）を使う
- 本文のセクションが空でも省略せず「なし」で埋める
- `cc-triage-scope` ラベルは Issue ライフサイクル上の重要ラベル。本スキルは付与のみ行い、削除は一切行わない（呼び出し側でも `gh issue edit --remove-label` の対象に含めてはならない）
- このスキルを編集する際は、フォーマットの変更が `answer-issue-questions` / `breakdown-issues` の両スキルに効くことを意識する（このスキルが2スキル共通の唯一の format source）
