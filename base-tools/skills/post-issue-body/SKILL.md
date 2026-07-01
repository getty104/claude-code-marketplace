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

呼び出し元スキル（`create-issue` / `create-issue-from-issue-number` / `update-issue`）から委譲される、Issue本文の整形と投稿を担う共有スキルです。

親スキルが「タスクの分析」「コードの分析」までを行ったあと、その分析結果を本スキルに渡すと、ここで以下を一括して実行します。

1. 「実装準備用Issue」の正規フォーマットに整形
2. 投稿前チェックの実施
3. `gh issue create` または `gh issue edit` の実行
4. 確認事項が渡されていればコメントとして投稿

このスキルは**ユーザーから直接呼び出される想定ではない**（親スキル内の「post-issue-bodyスキルで投稿する」というステップから Skill tool 経由で起動される）。直接呼ばれた場合は、入力 YAML が args に含まれていないことが多いので、親スキル（create-issue 等）の使用を促して終了する。

# Instructions

## 入力（args 経由の YAML ブロック）

### 呼び出し規約

呼び出し元の親スキル（`create-issue` / `create-issue-from-issue-number` / `update-issue`）は、**本スキル起動時の `args` に以下の YAML ブロックを文字列として渡す**こと。本スキルは `$ARGUMENTS` を YAML として機械的にパースして入力として扱う。

```yaml
mode: create  # create または edit
issue_number: 123  # edit時のみ必須、create時は省略
title: <Issueタイトル>
sections:
  依頼内容: |  # 任意。呼び出し元が「元のdescription／原文の依頼」を verbatim 保持したいときに指定する
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

assignee は呼び出し元から指定する必要はなく、本スキルが `gh api user --jq '.login'` で取得した「呼び出し時の gh ログインユーザー」を `mode=create` で自動的に `--assignee` として紐づける。

args に渡す YAML は上記の通り**トップレベルから直接書く**（ラッパキーなし）。

### args の渡し方

`Skill(skill='post-issue-body', args=<上記YAML文字列>)` の形で起動する。args は改行を含む複数行文字列として渡せる。

### 取り扱い規約

- 空セクションを省略しない。「なし」「該当なし」で埋める（後続スキルが「未記入」と区別できなくなるため）。
- args の YAML が壊れていたり項目が欠けている場合は、最低限の推定で埋める。`mode` と（edit時の）`issue_number` だけは推定不可なので欠けていたら中断する。
- args が空、もしくは YAML として解釈できない場合（直接ユーザー起動など）は、親スキル（`create-issue` / `create-issue-from-issue-number` / `update-issue`）の使用を促して中断する。

## Issueフォーマット（厳守）

このスキルが投稿するのは「コード分析済みの実装準備Issue」であり、本文は必ず以下の正規フォーマットに従う。

`triage-created-issue` や `exec-issue`（`read-github-issue` 経由）といった後続スキルは、Issue本文を読み取ってラベリング・タスク分解・実装を行う。セクションの過不足、順序の入れ替え、見出し名のゆらぎは後続スキルの判断を狂わせ、人がレビューする際の可読性も損なう。どのスキルが作っても同じ構造になるよう、このフォーマットを揃えることが目的なので、独自のアレンジは加えない。

### 本文テンプレート

`## 依頼内容` セクションは**任意**。呼び出し元が args の `sections.依頼内容` を渡した、または mode=edit で既存bodyに `## 依頼内容` が既に存在する場合のみ、本文の**先頭**（`## 概要` の前）に追加する。それ以外の場合は本文に含めない（既存の呼び出し元は現状の6セクション構成で従来通り動作する）。

```markdown
## 依頼内容
（このセクションは任意。呼び出し元が渡した「依頼内容」を verbatim。既存bodyに存在した場合は verbatim 再掲）

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

本文末尾の `<details><summary>変更ログ</summary>` は、Issueの作成・更新履歴を時系列で残す折りたたみセクション。後続スキルや人が「いつ・何を変えたか」を追えるようにするのが目的で、本文の他セクション（実装プラン等）と混同されないよう必ず折りたたみに入れる。

- **日付**は `date +%Y-%m-%d` で取得する（実行時に1回だけ取得すればよい）。
- **`mode=create`** では、初版エントリを1行だけ記載する（例: `- 2026-06-02: 初版作成 — <タスクの概要を一言>`）。
- **`mode=edit`** では、既存本文（ステップ1で `gh issue view --json body` 取得）の `<details>` ブロック内エントリを**1行も削らず verbatim で再掲**し、その末尾に今回の変更を1行追記する。heredocは本文全体を上書きするため、既存エントリを書き写さないとログが消える点に注意する。
- 既存本文に変更ログブロックが無い（旧フォーマット）の場合は、新たにブロックを作り、初回エントリとして今回の更新内容を1行記載する（過去分は遡及しない）。
- 1エントリは1行・簡潔に。何を変えたかが分かる粒度にとどめ（例: `要件に〇〇を追加`、`Explore再分析で実装プランを見直し`）、差分全文や冗長な説明は書かない。

### 「## 依頼内容」セクションの verbatim 保持ルール（mode=edit）

- args の `sections.依頼内容` が指定されている場合、その内容をそのまま `## 依頼内容` セクションとして本文の先頭に含める。
- args の `sections.依頼内容` が**未指定 or 空**で、かつ mode=edit で取得した既存bodyに `## 依頼内容` セクションが存在する場合は、その内容を**1行も削らず verbatim で再掲**する。これは変更ログと同じ趣旨で、heredocでの本文上書きにより過去のセクションを失うのを防ぐため。
- どちらにも該当しない場合（mode=create かつ args未指定、または mode=edit で既存bodyに `## 依頼内容` が無い）、`## 依頼内容` セクションは本文に含めない（従来の6セクション構成のまま）。

### 投稿前チェック（`gh` 実行の直前に必ず確認）

本文を `gh` に渡す直前に以下を確認し、1つでも満たさない場合は本文を直してから実行する。空になるセクションを省略せず「なし」で埋めるのは、後続スキルが「セクションが無い（＝未記入）」と「該当なし」を区別できないため。

- 見出しが `## 概要` → `## 要件` → `## 参照情報` → `## 直近関連変更（過去 30 日 / 直近 10 commit）` → `## 実装プラン` → `## 影響範囲` の順で、過不足なく並んでいる。`## 依頼内容` を含める条件を満たす場合は、`## 概要` の直前に `## 依頼内容` を1つだけ追加する（他の順序は変えない）
- テンプレート外の見出し（`##`）を追加していない（`## 依頼内容` は上記条件を満たす場合のみ許容。末尾の変更ログ折りたたみは見出しではないため対象外）
- 空になるセクションを省略せず「なし」で埋めている（`## 直近関連変更` は確認の結果に該当がなければ「該当なし」と明記する）
- `## 影響範囲` の直後に `<details><summary>変更ログ</summary>` の折りたたみブロックが1つだけあり、`</summary>` の後と `</details>` の前に空行がある（空行がないと GitHub で箇条書きが描画されない）
- 変更ログに最低1エントリある。`mode=edit` では既存エントリを verbatim で保持したうえで今回分を1行追記している
- `## 依頼内容` を含める場合、その内容は args の `sections.依頼内容`（明示指定時）または既存bodyの `## 依頼内容`（mode=edit で verbatim 再掲時）と**1文字も違わず一致**している

## 実行ステップ

### 1. args の YAML パース

`$ARGUMENTS` を YAML として解釈し、`mode` / `issue_number` / `title` / `sections` / `new_changelog_entry` / `labels` / `confirmation_items` を取り出す。`mode` が読み取れない、`mode=edit` で `issue_number` が読み取れない、または args が空ならば中断条件に従って終了する。

`labels` は配列。空 / 未指定なら `--label` フラグを一切付けない（空文字を渡すと `gh` が引数エラーで落ちるため）。`mode=edit` ではラベル指定を**無視する**（既存ラベルの剥がし合いを避けるため。ラベル付け替えは呼び出し元が `gh issue edit --add-label` / `--remove-label` で明示的に行う方針）。

### 2. (mode=edit のみ) 既存本文の取得

変更ログと（あれば）`## 依頼内容` を verbatim で再掲するため、対象 Issue の現在の body を取得する。

```bash
gh issue view <issue_number> --json body
```

取得した body の `<details><summary>変更ログ</summary>` ブロック内 `- YYYY-MM-DD: ...` 行を抽出し、新しい本文の同ブロックに**全行 verbatim** で書き写したうえで末尾に今回のエントリを1行追記する。

さらに、既存bodyに `## 依頼内容` セクションがあれば、その本文（次の `## 概要` またはEOF直前まで）を抽出しておく。args の `sections.依頼内容` が指定されていなければ、抽出した内容を新しい本文の `## 依頼内容` セクションに**verbatim 再掲**する（args 指定があればそちらを優先）。

対象 Issue の state が `CLOSED` の場合は、その旨を出力して中断する。

### 3. 本文の組み立てと投稿前チェック

「本文テンプレート」「変更ログ追記ルール」に従って本文を組み立てる。組み立て後、必ず「投稿前チェック」の項目を1つずつ確認する。1つでも満たさない場合は本文を直してから次へ進む。

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
- `gh` コマンドの本文渡しは**必ず `--body-file -` + heredoc**（`<<'EOF' ... EOF`）を使う。`--body "..."` は本文中の特殊文字でエスケープが頻繁に壊れるため使わない
- 本文のセクションが空でも省略せず「なし」「該当なし」で埋める
- 変更ログの既存エントリ保持は **mode=edit の最重要ポイント**。verbatim 再掲を怠ると履歴が消える
- 既存bodyに `## 依頼内容` セクションがある場合の verbatim 再掲も同様に重要。argsで上書き指定がなければ既存の依頼内容を消してはいけない
- `mode=create` では `--assignee "$ME"` で gh ログインユーザーを assignee に自動付与する（呼び出し元から指定する必要はない）。`mode=edit` では assignee を変更しない
- `labels` 引数は `mode=create` でのみ反映する。`mode=edit` では無視する（既存ラベルの剥がし合いを避けるため、ラベル付け替えは呼び出し元が `gh issue edit --add-label` 等で明示的に行う方針）
- このスキルを編集する際は、フォーマットの変更が `create-issue` / `create-issue-from-issue-number` / `update-issue` の3スキル全体に効くことを意識する（このスキルが3スキル共通の唯一の format source）
