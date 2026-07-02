---
name: post-issue-body
description: "INTERNAL/HELPER skill — do NOT invoke directly from a user query. This is the shared formatter/poster used by create-issue, create-issue-from-issue-number, and update-issue. It formats an implementation-ready GitHub Issue body, runs the pre-posting checklist, executes `gh issue create` or `gh issue edit`, and optionally posts a 確認事項 follow-up comment. Invoke this skill ONLY from one of the three parent skills via the Skill tool, after the parent has completed analysis. If a user asks to 'format an issue body' or similar, route them to the appropriate parent skill (/create-issue, /create-issue-from-issue-number, or /update-issue) rather than invoking this one directly."
user-invocable: false
context: fork
model: sonnet
effort: high
argument-hint: "<YAML input — see SKILL.md>"
---

# Post Issue Body

呼び出し元スキル（`create-issue` / `create-issue-from-issue-number` / `update-issue`）から委譲され、Issue本文の整形と投稿を担う共有スキル。親スキルの分析結果を受け取り、以下を一括実行する。

1. 「実装準備用Issue」の正規フォーマットに整形
2. 投稿前チェックの実施
3. `gh issue create` または `gh issue edit` の実行
4. 確認事項が渡されていればコメントとして投稿

ユーザーから直接呼び出される想定ではない（親スキル内のステップから Skill tool 経由で起動される）。直接呼ばれ、入力 YAML が args に無い場合は、親スキル（create-issue 等）の使用を促して終了する。

> **呼び出し側への必須ルール**: 本スキルを**絶対にバックグラウンド実行しないこと**。`Agent` ツール経由で呼び出す場合は **既定が `run_in_background: true`（バックグラウンド）** のため、**必ず `run_in_background: false` を明示指定** すること。`Skill` ツール経由の場合も `run_in_background: true` を指定してはならない（既定は同期）。呼び出し元（いずれも `claude-task-worker` から自動起動される可能性がある）は、本スキルが同期的に `gh issue create/edit` を完了し Issue URL を返したことを確認してからラベル遷移や後続の確認事項コメント投稿に進む設計であり、バックグラウンド化すると本文更新前に制御が戻り、後続処理が古い状態を前提に走って破綻する。

# Instructions

## 実行モードの制約: サブエージェント・サブスキル・Bashをバックグラウンド実行しないこと

本スキルは `context: fork` のサブエージェントとして起動されるが、**内部で呼び出す `Bash` / `Skill` / `Agent` も絶対にバックグラウンド実行しない**。

- `Bash` に `run_in_background: true` を指定しない。特に `gh issue create` / `gh issue edit` / `gh issue comment` は同期実行し、返却された Issue URL や成功ステータスを確認してから完了報告する
- コマンド末尾に `&` を付けたり、`nohup` / `disown` / `setsid` でデタッチしたりしない
- **`Agent` ツールは既定が `run_in_background: true`（バックグラウンド）**。呼び出しごとに **必ず `run_in_background: false` を明示指定** し、フォアグラウンドで同期的に結果を受け取ってから次の処理に進む。指定を省略した場合はバックグラウンドで走り、本スキルが未完のまま終了する
- `Skill` にも `run_in_background: true` を渡さない（既定は同期）
- `ScheduleWakeup` などで処理を後回しにしない

**理由**: 本スキルは呼び出し元へ「Issue URL と投稿完了ステータス」を同期返却する契約であり、バックグラウンド化すると `gh` 完了前に制御が戻り、URL 未取得のまま報告される・本文未反映のまま `cc-issue-created` が付与される、といった状態壊れが起きる。

## 入力（args 経由の YAML ブロック）

### 呼び出し規約

呼び出し元の親スキル（`create-issue` / `create-issue-from-issue-number` / `update-issue`）は、**本スキル起動時の `args` に以下の YAML ブロックを文字列として渡す**こと。本スキルは `$ARGUMENTS` を YAML として機械的にパースして入力として扱う。

```yaml
mode: create  # create または edit
issue_number: 123  # edit時のみ必須、create時は省略
title: <Issueタイトル>
sections:
  依頼内容: |  # 任意。呼び出し元が「元のdescription／原文の依頼」を verbatim 保持したいときに指定する。本文では折りたたみ（<details>）ブロックとして描画される
    （元の依頼内容を verbatim）
  概要: |
    （1-3行の概要）
  要件: |
    - 要件1
    - 要件2
  参照情報: |
    - ドキュメント: `<path>` — <説明>
    （無ければ "なし"）
  直近関連変更: |
    - `<commit hash>` <subject> — <影響>
    （無ければ "該当なし"）
  実装プラン: |
    1. フェーズ1
    2. フェーズ2
  影響範囲: |
    - `<path>` — <概略>
new_changelog_entry: <この作成・更新で変えた点を1行要約>
labels:  # 任意。0件ならキー自体を省略可。mode=create でのみ有効（mode=edit では無視する）
  - <ラベル名1>
  - <ラベル名2>
confirmation_items:  # 任意。0件ならキー自体を省略可
  - <質問1>
  - <質問2>
```

assignee は呼び出し元から指定不要。本スキルが `gh api user --jq '.login'` で取得した「呼び出し時の gh ログインユーザー」を `mode=create` で自動的に `--assignee` として紐づける。

args に渡す YAML は上記の通り**トップレベルから直接書く**（ラッパキーなし）。

### args の渡し方

`Skill(skill='post-issue-body', args=<上記YAML文字列>)` の形で起動する。args は改行を含む複数行文字列として渡せる。

### 取り扱い規約

- 空セクションを省略しない。「なし」「該当なし」で埋める（後続スキルが「未記入」と区別できなくなるため）。
- args の YAML が壊れていたり項目が欠けている場合は、最低限の推定で埋める。`mode` と（edit時の）`issue_number` だけは推定不可なので欠けていたら中断する。
- args が空、もしくは YAML として解釈できない場合（直接ユーザー起動など）は、親スキル（`create-issue` / `create-issue-from-issue-number` / `update-issue`）の使用を促して中断する。

## Issueフォーマット（厳守）

このスキルが投稿するのは「コード分析済みの実装準備Issue」であり、本文は必ず以下の正規フォーマットに従う。`triage-created-issue` や `exec-issue`（`read-github-issue` 経由）といった後続スキルは本文を読んでラベリング・タスク分解・実装を行うため、セクションの過不足・順序の入れ替え・見出し名のゆらぎは後続スキルの判断と人のレビュー可読性を損なう。独自のアレンジは加えない。

### 本文テンプレート

「依頼内容」セクションは**任意**、かつ**折りたたみ（`<details><summary>依頼内容</summary>`）ブロック**で描画する。呼び出し元が args の `sections.依頼内容` を渡した、または mode=edit で既存bodyに `<details><summary>依頼内容</summary>` ブロックが既に存在する場合のみ、本文の**先頭**（`## 概要` の前）に追加する。それ以外の場合は本文に含めない（従来の6セクション構成のまま）。

折りたたみにするのは、Issue を開いた直後に見えるべきは「Explore 再分析結果（概要・要件・実装プラン）」で、原文の依頼はデフォルト非表示・必要時に展開できる形が実用的なため。**注意**: 本文中に `<details>` ブロックは依頼内容と変更ログの2つ並び得るため、`<summary>` テキスト（`依頼内容` / `変更ログ`）で区別し、抽出・verbatim 比較の際は `<summary>依頼内容</summary>` を含むブロックだけを対象にする。

```markdown
<details>
<summary>依頼内容</summary>

（このセクションは任意。呼び出し元が渡した「依頼内容」を verbatim。既存bodyに存在した場合は verbatim 再掲）

</details>

## 概要
（タスクの目的と達成すべきゴールを1-3行で記述）

## 要件
- （機能要件・非機能要件を箇条書き。1項目1行）

## 参照情報
- ドキュメント: `<path>` — <関連箇所の説明>
- デザイン: `<path>` — <関連箇所の説明>
（該当する参照情報がなければ `- なし` の1行だけ書く）

## 直近関連変更（過去 30 日 / 直近 10 commit）
- `<commit hash>` <subject> — <Issue/PR への影響>
（直近変更や進行中 PR がなければ「該当なし」と1行だけ書く）

## 実装プラン
1. （フェーズ1）
2. （フェーズ2）
3. （フェーズ3）

## 影響範囲
- `<path>` — <変更の概略>

<details>
<summary>変更ログ</summary>

- YYYY-MM-DD: <この作成・更新で変えた点を1行で簡潔に>

</details>
```

### 変更ログ（折りたたみ）の追記ルール

本文末尾の `<details><summary>変更ログ</summary>` は、Issueの作成・更新履歴を時系列で残す折りたたみセクション。「いつ・何を変えたか」を追えるようにするのが目的で、他セクションと混同されないよう必ず折りたたみに入れる。

- **日付**は `date +%Y-%m-%d` で取得する（実行時に1回だけ取得すればよい）。
- **`mode=create`** では、初版エントリを1行だけ記載する（例: `- 2026-06-02: 初版作成 — <タスクの概要を一言>`）。
- **`mode=edit`** では、既存本文（`gh issue view --json body` で取得）の `<details>` ブロック内エントリを**1行も削らず verbatim で再掲**し、その末尾に今回の変更を1行追記する。heredocは本文全体を上書きするため、既存エントリを書き写さないとログが消える点に注意する。
- 既存本文に変更ログブロックが無い（旧フォーマット）場合は、新たにブロックを作り、初回エントリとして今回の更新内容を1行記載する（過去分は遡及しない）。
- 1エントリは1行・簡潔に。何を変えたかが分かる粒度にとどめ（例: `要件に〇〇を追加`、`Explore再分析で実装プランを見直し`）、差分全文や冗長な説明は書かない。

### 「依頼内容」折りたたみブロックの verbatim 保持ルール

- args の `sections.依頼内容` が指定されている場合、その内容を `<details><summary>依頼内容</summary>` ブロックの中身として本文の先頭に含める。`<summary>` の直後と `</details>` の直前には必ず1行の空行を入れる（空行がないと GitHub でマークダウンが描画されない）。
- args の `sections.依頼内容` が**未指定 or 空**で、かつ mode=edit で取得した既存bodyに `<details><summary>依頼内容</summary>` ブロックが存在する場合は、そのブロック内の中身を**1行も削らず verbatim で再掲**する（変更ログと同趣旨で、heredoc上書きによる過去ブロックの喪失を防ぐため）。
- どちらにも該当しない場合（mode=create かつ args未指定、または mode=edit で既存bodyに同ブロックが無い）、依頼内容ブロックは本文に含めない（従来の6セクション構成のまま）。
- **旧フォーマットとの互換**: mode=edit で取得した既存bodyに、折りたたみになっていない裸の `## 依頼内容` セクションが存在する場合（本フォーマット移行前のIssue）は、その本文を切り出して `<details><summary>依頼内容</summary>` ブロックに詰め替えて再掲する（内容は verbatim、体裁だけ現行フォーマットに揃える）。

### 投稿前チェック（`gh` 実行の直前に必ず確認）

本文を `gh` に渡す直前に以下を確認し、1つでも満たさない場合は本文を直してから実行する。

- 見出しが `## 概要` → `## 要件` → `## 参照情報` → `## 直近関連変更（過去 30 日 / 直近 10 commit）` → `## 実装プラン` → `## 影響範囲` の順で、過不足なく並んでいる
- テンプレート外の見出し（`##`）を追加していない（末尾の変更ログ折りたたみは見出しではないため対象外）
- 依頼内容ブロックを含める条件を満たす場合は、`## 概要` の**直前**に `<details><summary>依頼内容</summary>` ブロックを1つだけ配置している。`## 依頼内容` のような裸の見出し形式にはしない（旧フォーマット互換で読み込むケースを含めて、書き出しは必ず折りたたみで統一）
- 依頼内容ブロックの `<summary>依頼内容</summary>` 直後と `</details>` 直前には空行がある（空行がないと GitHub でマークダウンが描画されない）
- 空になるセクションを省略せず「なし」で埋めている（`## 直近関連変更` は確認の結果に該当がなければ「該当なし」と明記する）
- `## 影響範囲` の直後に `<details><summary>変更ログ</summary>` の折りたたみブロックが1つだけあり、`</summary>` の後と `</details>` の前に空行がある
- 変更ログに最低1エントリある。`mode=edit` では既存エントリを verbatim で保持したうえで今回分を1行追記している
- 依頼内容ブロックを含める場合、その中身は args の `sections.依頼内容`（明示指定時）または既存bodyの `<details><summary>依頼内容</summary>` の中身（mode=edit で verbatim 再掲時、旧フォーマット互換で `## 依頼内容` 本文から詰め替える場合も含む）と**1文字も違わず一致**している
- 本文中に `<details>` ブロックが 2 つある場合、`<summary>依頼内容</summary>` は本文先頭側、`<summary>変更ログ</summary>` は末尾側に配置し、`<summary>` テキストが取り違えられていない

## 実行ステップ

### 1. args の YAML パース

`$ARGUMENTS` を YAML として解釈し、`mode` / `issue_number` / `title` / `sections` / `new_changelog_entry` / `labels` / `confirmation_items` を取り出す。`mode` が読み取れない、`mode=edit` で `issue_number` が読み取れない、または args が空ならば中断条件に従って終了する。

`labels` は配列。空 / 未指定なら `--label` フラグを一切付けない（空文字を渡すと `gh` が引数エラーで落ちる）。`mode=edit` ではラベル指定を**無視する**（既存ラベルの剥がし合いを避けるため。ラベル付け替えは呼び出し元が `gh issue edit --add-label` / `--remove-label` で明示的に行う方針）。

### 2. (mode=edit のみ) 既存本文の取得

変更ログと（あれば）依頼内容ブロックを verbatim で再掲するため、対象 Issue の現在の body を取得する。

```bash
gh issue view <issue_number> --json body
```

取得した body の `<details><summary>変更ログ</summary>` ブロック内 `- YYYY-MM-DD: ...` 行を抽出し、新しい本文の同ブロックに**全行 verbatim** で書き写したうえで末尾に今回のエントリを1行追記する。

さらに、既存bodyから「依頼内容」の中身を次の優先順で抽出しておく:

1. `<details><summary>依頼内容</summary>` ブロックがあれば、その内側（`<summary>` の閉じタグ直後から `</details>` の直前まで、先頭と末尾の空行1つは正規化してよい）を verbatim で切り出す。
2. 1が無く、裸の `## 依頼内容` セクションがある場合（旧フォーマット）は、その見出し直後から次の `## ` 見出しまたはEOF直前までを verbatim で切り出す。
3. どちらも無ければ「依頼内容」は無しとして扱う。

args の `sections.依頼内容` が未指定 or 空で、上記1または2で中身を抽出できた場合は、その内容を新しい本文の `<details><summary>依頼内容</summary>` ブロックに**verbatim 再掲**する（args 指定があればそちらを優先）。旧フォーマット（2）で抽出した場合も、書き出しは必ず折りたたみブロックに詰め替える。

対象 Issue の state が `CLOSED` の場合は、その旨を出力して中断する。

### 3. 本文の組み立てと投稿前チェック

「本文テンプレート」「変更ログ追記ルール」に従って本文を組み立て、必ず「投稿前チェック」の項目を1つずつ確認する。1つでも満たさない場合は本文を直してから次へ進む。

### 4. `gh` で投稿

**`--body "..."` 形式は使わない**。本文中のバッククォート・`$`・`!`・改行でエスケープが頻繁に壊れるため、必ず `--body-file -` + heredoc（`<<'EOF'` でクォート、シェル展開を抑止）を使う。

#### mode=create

YAML 入力に `labels` があれば、各ラベルを `--label <ラベル名>` として `EXTRA_FLAGS` 配列に追加する。値が無ければフラグごと省略する（空文字を渡すと `gh` が引数エラーで落ちる）。`--label` は同じ値を複数回渡す形式で複数指定する。

```bash
ME=$(gh api user --jq '.login')

# YAML の labels を --label の連続フラグに展開する。
# 例: labels=[cc-triage-scope, type-feature] のとき EXTRA_FLAGS=(--label cc-triage-scope --label type-feature)
# labels が空 / 未指定なら何も push しない。
EXTRA_FLAGS=()
# for L in "${LABELS[@]}"; do EXTRA_FLAGS+=(--label "$L"); done

gh issue create \
  --title "<タイトル>" \
  --assignee "$ME" \
  "${EXTRA_FLAGS[@]}" \
  --body-file - <<'EOF'
## 概要
...

## 要件
- ...

## 参照情報
- ...

## 直近関連変更（過去 30 日 / 直近 10 commit）
- ...

## 実装プラン
1. ...

## 影響範囲
- ...

<details>
<summary>変更ログ</summary>

- YYYY-MM-DD: 初版作成 — <一言>

</details>
EOF
```

成功時、コマンドが標準出力に返す Issue URL を保持する。

#### mode=edit

`--title` は呼び出し元が変更を希望する場合のみ付ける（無指定なら省略）。

```bash
gh issue edit <issue_number> \
  --title "<更新後タイトル>" \
  --body-file - <<'EOF'
## 概要
...

## 要件
- ...

## 参照情報
- ...

## 直近関連変更（過去 30 日 / 直近 10 commit）
- ...

## 実装プラン
1. ...

## 影響範囲
- ...

<details>
<summary>変更ログ</summary>

- YYYY-MM-DD: <既存エントリを verbatim 再掲>
- YYYY-MM-DD: <今回追加するエントリ>

</details>
EOF
```

成功後、対象 Issue の URL を保持する。

### 5. 確認事項のコメント投稿（任意）

呼び出し元から渡された「確認事項」が**1件以上**ある場合のみコメントする。0件ならスキップする。コメントも `--body-file -` + heredoc を使う。

```bash
gh issue comment <issue_number> --body-file - <<'EOF'
## 確認事項
- <質問1>
- <質問2>
EOF
```

### 6. 呼び出し元への返却

以下を出力して、呼び出し元の親スキルが「最終報告」で使えるようにする。

- 対象 Issue の URL
- `mode`（create / edit）
- 確認事項コメントの有無（true / false）

## 中断条件

以下のいずれかに該当する場合のみ、理由を1-2行で出力して**即中断**する。

- args が空、もしくは YAML として解釈できない
- `mode` が `create` でも `edit` でもない
- `mode=edit` で `issue_number` が解釈できない
- `mode=edit` で `gh issue view` が失敗、または対象 Issue が `CLOSED`
- `gh issue create` / `gh issue edit` / `gh issue comment` が失敗し、再試行しても解消しない

## 注意事項

- 本スキルは**コードを一切変更しない**。Issue の作成・更新・コメントのみを行う
- `gh` の本文渡しは**必ず `--body-file -` + heredoc**（`<<'EOF' ... EOF`）を使う
- 本文のセクションが空でも省略せず「なし」「該当なし」で埋める
- 変更ログの既存エントリ保持は **mode=edit の最重要ポイント**。verbatim 再掲を怠ると履歴が消える
- 既存bodyの依頼内容ブロック（新フォーマットの `<details><summary>依頼内容</summary>` / 旧フォーマットの裸の `## 依頼内容`）の verbatim 再掲も同様に重要。argsで上書き指定がなければ既存の依頼内容を消してはいけない。旧フォーマットで読み込んだ場合でも書き出しは折りたたみで統一する
- `mode=create` では `--assignee "$ME"` で gh ログインユーザーを assignee に自動付与する。`mode=edit` では assignee を変更しない
- `labels` 引数は `mode=create` でのみ反映し、`mode=edit` では無視する
- このスキルを編集する際は、フォーマットの変更が `create-issue` / `create-issue-from-issue-number` / `update-issue` の3スキル全体に効くことを意識する（このスキルが3スキル共通の唯一の format source）
