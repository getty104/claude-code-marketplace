---
name: post-issue-body
description: "INTERNAL/HELPER skill — do NOT invoke directly from a user query. This is the shared formatter/poster used by create-issue, create-issue-from-issue-number, and update-issue. It formats an implementation-ready GitHub Issue body (label cc-issue-created), runs the pre-posting checklist, executes `gh issue create` or `gh issue edit`, and optionally posts a 確認事項 follow-up comment. Invoke this skill ONLY from one of the three parent skills via the Skill tool, after the parent has completed analysis. If a user asks to 'format an issue body' or similar, route them to the appropriate parent skill (/create-issue, /create-issue-from-issue-number, or /update-issue) rather than invoking this one directly."
user-invocable: false
context: fork
argument-hint: "[mode=create|edit issue_number=<N>]"
---

# Post Issue Body

呼び出し元スキル（`create-issue` / `create-issue-from-issue-number` / `update-issue`）から委譲される、Issue本文の整形と投稿を担う共有スキルです。

親スキルが「タスクの分析」「コードの分析」までを行ったあと、その分析結果を本スキルに渡すと、ここで以下を一括して実行します。

1. 「実装準備用Issue」の正規フォーマットに整形
2. 投稿前チェックの実施
3. `gh issue create` または `gh issue edit` の実行
4. 確認事項が渡されていればコメントとして投稿

このスキルは**ユーザーから直接呼び出される想定ではない**（親スキル内の「post-issue-bodyスキルで投稿する」というステップから Skill tool 経由で起動される）。直接呼ばれた場合は、分析結果が直前コンテキストに揃っていないことが多いので、親スキル（create-issue 等）の使用を促して終了する。

# Instructions

## 入力（args + 直前コンテキストの YAML ブロック）

### 呼び出し規約

呼び出し元の親スキル（`create-issue` / `create-issue-from-issue-number` / `update-issue`）は、本スキルを Skill tool で起動する直前に、**以下の YAML ブロックをコンテキストに出力する**こと。本スキルはこの YAML を機械的に拾って入力として扱う。

```yaml
post-issue-body-input:
  mode: create  # create または edit
  issue_number: 123  # edit時のみ必須、create時は省略
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
    直近関連変更: |
      - `<commit hash>` <subject> — <影響>
      （無ければ "該当なし"）
    実装プラン: |
      1. フェーズ1
      2. フェーズ2
    影響範囲: |
      - `<path>` — <概略>
  new_changelog_entry: <この作成・更新で変えた点を1行要約>
  confirmation_items:  # 任意。0件ならキー自体を省略可
    - <質問1>
    - <質問2>
```

### args（Skill tool に渡す）

最低限 `mode=create` または `mode=edit issue_number=<N>` を args として渡す。詳細データは YAML ブロック側に書く（args の文字数制限に配慮）。

### 取り扱い規約

- 空セクションを省略しない。「なし」「該当なし」で埋める（後続スキルが「未記入」と区別できなくなるため）。
- YAML が壊れていたり項目が欠けている場合は、直前コンテキストから合理的に推定する。`mode` と（edit時の）`issue_number` だけは推定不可なので欠けていたら中断する。
- 親スキルが YAML ブロックを出力せずに本スキルを呼んだ場合（直接呼び出しなど）は、直前コンテキストの自由形式テキストから best-effort で読み取り、不明箇所は「不明」「該当なし」で埋める。重大な情報が無ければ中断する。

## Issueフォーマット（厳守）

このスキルが投稿するのは「コード分析済みの実装準備Issue」（ラベル `cc-issue-created`）であり、本文は必ず以下の正規フォーマットに従う。

`triage-created-issue` や `exec-issue`（`read-github-issue` 経由）といった後続スキルは、Issue本文を読み取ってラベリング・タスク分解・実装を行う。セクションの過不足、順序の入れ替え、見出し名のゆらぎは後続スキルの判断を狂わせ、人がレビューする際の可読性も損なう。どのスキルが作っても同じ構造になるよう、このフォーマットを揃えることが目的なので、独自のアレンジは加えない。

### 本文テンプレート

```markdown
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

### 投稿前チェック（`gh` 実行の直前に必ず確認）

本文を `gh` に渡す直前に以下を確認し、1つでも満たさない場合は本文を直してから実行する。空になるセクションを省略せず「なし」で埋めるのは、後続スキルが「セクションが無い（＝未記入）」と「該当なし」を区別できないため。

- 見出しが `## 概要` → `## 要件` → `## 参照情報` → `## 直近関連変更（過去 30 日 / 直近 10 commit）` → `## 実装プラン` → `## 影響範囲` の順で、過不足なく並んでいる
- テンプレート外の見出し（`##`）を追加していない（末尾の変更ログ折りたたみは見出しではないため対象外）
- 空になるセクションを省略せず「なし」で埋めている（`## 直近関連変更` は確認の結果に該当がなければ「該当なし」と明記する）
- `## 影響範囲` の直後に `<details><summary>変更ログ</summary>` の折りたたみブロックが1つだけあり、`</summary>` の後と `</details>` の前に空行がある（空行がないと GitHub で箇条書きが描画されない）
- 変更ログに最低1エントリある。`mode=edit` では既存エントリを verbatim で保持したうえで今回分を1行追記している

## 実行ステップ

### 1. (mode=edit のみ) 既存本文の取得

変更ログを verbatim で再掲するため、対象 Issue の現在の body を取得する。

```bash
gh issue view <issue_number> --json body
```

取得した body の `<details><summary>変更ログ</summary>` ブロック内 `- YYYY-MM-DD: ...` 行を抽出し、新しい本文の同ブロックに**全行 verbatim** で書き写したうえで末尾に今回のエントリを1行追記する。

対象 Issue の state が `CLOSED` の場合は、その旨を出力して中断する。

### 2. 本文の組み立てと投稿前チェック

「本文テンプレート」「変更ログ追記ルール」に従って本文を組み立てる。組み立て後、必ず「投稿前チェック」の項目を1つずつ確認する。1つでも満たさない場合は本文を直してから次へ進む。

### 3. `gh` で投稿

**`--body "..."` 形式は使わない**。本文中のバッククォート・`$`・`!`・改行でエスケープが頻繁に壊れるため、必ず `--body-file -` + heredoc（`<<'EOF'` でクォート、シェル展開を抑止）を使う。

#### mode=create

```bash
ME=$(gh api user --jq '.login')

gh issue create \
  --title "<タイトル>" \
  --assignee "$ME" \
  --label "cc-issue-created" \
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

`--remove-label` は使用しない（既存ラベルは保持する）。`--title` は呼び出し元が変更を希望する場合のみ付ける（無指定なら省略）。

```bash
gh issue edit <issue_number> \
  --title "<更新後タイトル>" \
  --add-label "cc-issue-created" \
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

### 4. 確認事項のコメント投稿（任意）

呼び出し元から渡された「確認事項」が**1件以上**ある場合のみコメントする。0件ならスキップする。コメントも `--body-file -` + heredoc を使う。

```bash
gh issue comment <issue_number> --body-file - <<'EOF'
## 確認事項
- <質問1>
- <質問2>
EOF
```

### 5. 呼び出し元への返却

以下を出力して、呼び出し元の親スキルが「最終報告」で使えるようにする。

- 対象 Issue の URL
- `mode`（create / edit）
- 確認事項コメントの有無（true / false）

## 中断条件

以下のいずれかに該当する場合のみ、理由を1-2行で出力して**即中断**する。

- `mode` が `create` でも `edit` でもない
- `mode=edit` で `issue_number` が解釈できない
- `mode=edit` で `gh issue view` が失敗、または対象 Issue が `CLOSED`
- `gh issue create` / `gh issue edit` / `gh issue comment` が失敗し、再試行しても解消しない
- 親スキルからの分析結果が直前コンテキストに無く、推定もできない（直接ユーザー起動された場合など）

## 注意事項

- 本スキルは**コードを一切変更しない**。Issue の作成・更新・コメントのみを行う
- `gh` コマンドの本文渡しは**必ず `--body-file -` + heredoc**（`<<'EOF' ... EOF`）を使う。`--body "..."` は本文中の特殊文字でエスケープが頻繁に壊れるため使わない
- 本文のセクションが空でも省略せず「なし」「該当なし」で埋める
- 変更ログの既存エントリ保持は **mode=edit の最重要ポイント**。verbatim 再掲を怠ると履歴が消える
- このスキルを編集する際は、フォーマットの変更が `create-issue` / `create-issue-from-issue-number` / `update-issue` の3スキル全体に効くことを意識する（このスキルが3スキル共通の唯一の format source）
