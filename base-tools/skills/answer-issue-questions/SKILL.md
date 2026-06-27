---
name: answer-issue-questions
description: "GitHub Issueの確認事項に対して、コードベースやドキュメントを徹底的に調査し、根拠に基づいた回答を提供するスキル。Issueの最後のコメントに含まれる確認事項を調査・回答し、コメントに追記する。"
argument-hint: "[issue-number]"
hooks:
  Stop:
    - matcher: ""
      hooks:
        - type: command
          command: docker compose down --volumes --remove-orphans
---

# Answer Issue Questions

GitHub Issueの最後のコメントに含まれる確認事項を調査し、根拠に基づいた回答を提供するスキルです。

# Instructions

## 入力

- Issue番号: `$0`

## 実行ステップ

### ステップ1: Issueとコメントの取得

対象Issueの情報と最後のコメントを取得する。

```
gh issue view $0 --json number,title,body,labels
gh issue view $0 --json comments --jq '.comments[-1]'
```

最後のコメントに確認事項が含まれているか確認する。確認事項がない場合はその旨を報告して終了する。

### ステップ2: タスクの分析

確認事項の内容を理解するために、以下のドキュメントを読み込む。

- `docs/`配下のドキュメントファイル
- `design/`配下のPencilファイル（`.pen`）: `inspect-pencil-node` スキルで対象Nodeの属性データとスクリーンショットを取得して内容を確認する（`.pen` は暗号化バイナリのため `Read`/`Grep` は使えない）

これらの情報をもとに、確認事項の背景・目的・関連する仕様を把握する。

本スキルはコードを変更しない（コメント編集と派生Issue作成のみ）ため、確認事項への回答過程で `.pen` の編集が必要と判明した場合は本スキル内では編集せず、以下のいずれかで後続タスクへ委譲する：

- 確認事項への回答内で「対応には `pencil-design-updater` エージェントによる `<対象 .pen>` の更新が必要」と明示する
- 独立したタスクとして切り出すべき場合は、ステップ5の派生Issue作成（`post-scope-issue-body` 経由）で「`pencil-design-updater` エージェントで `<対象 .pen>` を更新する」旨を実装プラン/要件に含めて起票する

`.pen` 編集は `pencil-design-updater` 専任で、手で `pencil` コマンドを直接組み立てたり frontend-implementer / general-purpose-assistant 等で代用したりしない（`edit-pencil-design` スキルに集約された運用ルール — 同パス上書き・差分Node特定・`snapshots/` 出力 — を逸脱させないため）。

### ステップ3: コードの分析

Explore サブエージェントで確認事項に関連するコードベースをできるだけ詳細に分析する。

分析の観点：
- 確認事項で言及されている機能やコンポーネントの実装状況
- 関連する設定ファイルの内容
- 必要に応じたgit履歴の確認
- コードベース内の関連パターンの検索
- 複数のソースを相互参照して調査結果を検証する

UIや画面挙動に関する確認事項の場合は、`playwright-cli`スキルを使用して実際の画面上での動作を確認する。
- 該当ページにアクセスしてレンダリング結果やレイアウトをスクリーンショットで確認する
- インタラクション（クリック、入力、遷移など）の挙動を実際に操作して検証する
- DOM構造やコンソールログを確認して問題の有無を調査する
- 確認結果は回答の根拠として引用する（スクリーンショットやログの抜粋を含める）

### ステップ4: 回答の作成とコメント編集

ステップ2・3の分析結果をもとに、各確認事項に対して回答を作成し、最後のコメントを編集して追記する。
回答が必要な確認事項が複数ある場合は、全ての項目に対して回答を追記する。

#### 回答の構造

各確認事項への回答は以下の要素を含める：
- **結論**: 質問に対する直接的な回答
- **根拠**: 結論を裏付けるエビデンスと推論（コードを引用する際はファイルパスと行番号を提供する）
- **リスク・注意点**: リスク、注意事項、エッジケース（該当する場合）
- **推奨アクション**: 推奨される次のステップ（該当する場合）

#### 品質基準

- 推測する場合は必ずその旨を明示する
- 回答は簡潔かつ網羅的にする
- 不確実な場合は、確信度と追加調査の必要性を明示する
- 事実（コードやドキュメントで確認済み）と仮定を区別する

#### 回答の追記フォーマット

```
## 回答

### 確認事項1
（回答内容）

### 確認事項2
（回答内容）

...（未回答の確認事項があれば同様に追加）
```

#### コメントの編集コマンド

```
gh api repos/{owner}/{repo}/issues/comments/<コメントID> -X PATCH -f body="<編集後のコメント全文>"
```

### ステップ5: 関連Issueの作成（post-scope-issue-body へ委譲）

確認事項・回答内容から、現在のIssueとは別に対応が必要なタスクがあると判断された場合は、追加でIssueを作成すること。

以下のいずれかに該当する場合が対象：
- 現在のIssueのスコープに含めるべきではない独立したタスクがある場合
- 前提条件として先に対応すべき別タスクが見つかった場合
- 関連するが別途管理すべきバグや改善点が発見された場合

該当するタスクがない場合はこのステップをスキップする。

#### 責務の分担

本文整形・投稿前チェック・`gh issue create` の実行は `post-scope-issue-body` スキルに委譲する。本文テンプレート・投稿前チェックリスト・heredoc 投稿コマンドはすべて `post-scope-issue-body` 側に集約されているため、本スキル内では再記述しない（重複を避けるため、また `post-scope-issue-body` との不整合を生まないため）。

本スキルでは「派生タスクの抽出」と「`$0` と同じ親Issueへの sub-issue 紐付け」のみを担う。

#### 5-1. post-scope-issue-body スキルで Issue を作成

該当するタスクごとに、以下の YAML ブロックを**そのまま args として** Skill tool で `post-scope-issue-body` を起動する。`post-scope-issue-body` は args（`$ARGUMENTS`）を YAML として機械的にパースして入力として扱う規約になっている。

```yaml
mode: create
title: <タスク名をそのまま>
sections:
  概要: |
    （1-3行）
  要件: |
    - ...
    （無ければ "なし"）
  参照情報: |
    - ドキュメント: `<path>` — <説明>
    （無ければ "なし"）
  優先度: High  # High / Medium / Low のいずれか
  見積もり規模: M  # S / M / L / XL のいずれか
# 依存関係は GitHub ネイティブ relationships で表現する。
# 必要に応じて以下を渡す（不要なら項目ごと省略）。
# blocked_by: [<確定済みIssue番号>, ...]   # 例: $0 をブロック先にする場合
# parent: <親Issue番号>                   # 通常は post-creation の --add-sub-issue で best-effort リンクするため未使用
```

Skill tool 呼び出しは `Skill(skill='post-scope-issue-body', args=<上記YAML文字列>)`（必要なら plugin namespace 付きで `base-tools:post-scope-issue-body`）。args は改行を含む複数行文字列としてそのまま渡す。`post-scope-issue-body` が完了後、作成された Issue URL と Issue 番号を返す。

`post-scope-issue-body` の失敗（gh コマンド失敗・本文チェック不通過の解消不能等）はそのまま本ステップの中断条件となる。エラーメッセージを最終報告に含めて中断する（既に作成済みのIssueは残すこと）。

#### 5-2. `$0` と同じ親Issueに新Issueを sub-issue として紐付け

`post-scope-issue-body` が返した新Issue URL を、`$0` の親Issueに sub-issue として紐付ける。これにより新Issueは `$0` の兄弟（同じ親の下にぶら下がる sub-issue）になる。`$0` に親Issueが無い場合はスキップする。

親Issueの番号取得は GitHub REST `/parent` エンドポイントを `gh api` 経由で利用し、sub-issue 紐付け自体は `gh` CLI v2.94.0 以降で追加された `gh issue edit --add-sub-issue` ネイティブコマンドを使う（database ID の自前取得が不要）。`gh api` のパス中 `{owner}` / `{repo}` プレースホルダは現在のリポジトリで自動展開される。

```bash
# 1. $0 の親Issueの番号を取得。
#    GitHub の /parent エンドポイントが「親無し」をどう返すか（404 か 200+null）に依存しないよう、
#    `// empty` で「フィールドが無ければ何も出力しない」と明示し、加えて API 失敗（404/権限/ネットワーク）も
#    `2>/dev/null || true` でまとめてスキップ扱いにする。いずれの場合も PARENT_NUMBER は空文字列になる。
PARENT_NUMBER=$(gh api "repos/{owner}/{repo}/issues/$0/parent" --jq '.number // empty' 2>/dev/null || true)

if [ -n "$PARENT_NUMBER" ]; then
  # 2. 新Issue URL から番号を抽出（URL末尾セグメント）
  NEW_ISSUE_NUMBER=$(basename "$NEW_ISSUE_URL")

  # 3. 親Issueに新Issueを sub-issue として追加。gh v2.94.0+ のネイティブコマンドを使う。
  #    Issue 作成と紐付けを分離してあるのは「Issue 作成は確実に成功させ、紐付けは best-effort」というポリシーのため
  #    （`gh issue create --parent` で一発作成も可能だが、--parent 検証で失敗すると Issue すら作成されない）
  gh issue edit "$PARENT_NUMBER" --add-sub-issue "$NEW_ISSUE_NUMBER"
fi
```

`gh issue edit --add-sub-issue` が失敗した場合（権限不足、`gh` バージョン要件未達、API 仕様変更等）は、新Issue自体は既に作成済みなので sub-issue 紐付けエラーを出力に残したうえで処理を続行する（Issue作成のロールバックはしない）。

`$0` に親Issueが無い場合は `PARENT_NUMBER` が空文字列になるので紐付けをスキップする。新Issueは親Issueにぶら下げず単独の Issue として残る。最終報告に「親Issueが無いため sub-issue 紐付けはスキップ」と1行で記録するだけで良い。

#### 5-3. 複数Issue作成時の順序

複数の派生タスクを作成する場合は、`post-scope-issue-body` を1つずつ順に呼ぶ。依存関係のあるタスクは、依存先のIssue番号が確定してから（つまり依存先の `post-scope-issue-body` 呼び出しが完了してから）、その番号を `blocked_by:` リストに入れた YAML を args として渡して起動する。本文への `## 依存関係` セクション書き込みは廃止済み（GitHub ネイティブ relationships に移行）。

## 重要な制約

- `cc-triage-scope`ラベルがIssueに付与されている場合、いかなる操作においても**絶対に削除しない**こと
- `gh issue edit`で`--remove-label`を使用する際は`cc-triage-scope`を対象に含めないこと

## 出力形式

処理結果を以下の形式で返す：

- Issue番号
- 回答した確認事項の数
- 実行したアクション（コメント編集、Issue作成など）
- 作成した追加Issue（ある場合はIssue番号とURL、および sub-issue として紐付けた親Issueの番号。親Issueが無くスキップした場合はその旨）
