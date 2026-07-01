---
name: triage-pr
description: Triage a single GitHub PR by PR number. Check out the PR's branch, detect conflicts with the target branch via `gh pr status` (and label the PR with `cc-resolve-conflict` if any are found), generate and evaluate a fix plan via create-review-fix-plan, then take action (add cc-fix-onetime label if fixes are needed, or merge the PR if it's ready).
argument-hint: "[pr-number]"
hooks:
  Stop:
    - matcher: ""
      hooks:
        - type: command
          command: docker compose down --volumes --remove-orphans
---

# Triage PR

指定されたPR番号のPRに対して、コンフリクト解消から修正プランの評価、最終アクション（ラベル付与またはマージ）までを一貫して実行するスキルです。
このスキルが呼び出された際には、Instructionsに従って、PRの状態を確認し、適切なアクションを実行してください。

## このスキルがやること・やらないこと

**やること**:
- ステップ1のコンフリクト検知（`gh pr status`で確認し、コンフリクトがあれば`cc-resolve-conflict`ラベル付与のみで終了）
- ステップ2の修正プラン生成と評価（プランの分析・判定のみ）
- ステップ3のラベル付与（`cc-fix-onetime`）またはマージ

**絶対にやらないこと**:
- **PRのコード修正・実装**: 修正プランで「対応すべき」と判定された項目があっても、このスキル内では一切コードを変更しない。修正の実行は`cc-fix-onetime`ラベル付与後に別スキル（`fix-review-point`など）の責務となる
- **コンフリクト解消の直接実行**: rebase・コンフリクトファイルの編集・force-pushはこのスキルでは行わない。コンフリクトが検知されたら`cc-resolve-conflict`ラベルを付けて終了する。実際の解消は同ラベルをトリガーに別スキル（`resolve-pr-conflict`等）が担当する
- **`create-review-fix-plan`が返したプランの実行**: プランはあくまで判定材料として読むだけで、Edit/Write/MultiEdit等の編集ツールでファイルを変更してはならない
- **新規コミットの作成**: コミット・push・commit amendを行わない
- **テスト追加・Lint修正・リファクタリング**: 評価対象であっても、このスキルでは実行せずラベル付与にとどめる

ファイル編集ツール（`Edit` / `Write` / `MultiEdit` / `NotebookEdit`）はこのスキルの本文では一切呼び出さない。コードを触る作業はすべて「ラベル付与 → 別スキルが拾って実行」の流れに委ねる（ステップ1の`cc-resolve-conflict`、ステップ3パターンAの`cc-fix-onetime`）。

# Instructions

!`git fetch -p >/dev/null 2>&1`
!`gh pr checkout $ARGUMENTS >/dev/null 2>&1`

## 実行モードの制約: サブエージェント・サブスキル・Bashをバックグラウンド実行しないこと

本スキルは `claude-task-worker` の `triage-pr` ワーカー（`cc-triage-scope` ラベル）から自動起動される想定である。ワーカーはスキルプロセスの同期完了を根拠に `cc-fix-onetime` の付与やマージ、`cc-triage-scope` の除去を進めるため、**本スキル内部で呼び出す `Agent` / `Skill` / `Bash` を絶対にバックグラウンド実行しないこと**。具体的には次を守る。

- `Agent` / `Skill` ツール呼び出し時に `run_in_background: true` を指定しない。特に `create-review-fix-plan` の呼び出しは、返却された修正プランの構造化サマリを受け取ってから判定・ラベル付与に進む必要がある
- 同一メッセージ内で複数の `Agent` / `Skill` を並列に投げるのは「並列実行」であって「バックグラウンド実行」ではないため許容される（各サブエージェントの完了はその場で同期的に待つ）
- `Bash` ツール呼び出し時にも `run_in_background: true` を指定しない。シェルコマンド末尾に `&` を付けたり、`nohup` / `disown` / `setsid` などでプロセスをデタッチしたりしない
- `ScheduleWakeup` などで処理を後回しにすることも行わない

**理由**: バックグラウンド化するとサブエージェント/子スキル/子プロセスの完了前に本スキルが終了してしまい、`claude-task-worker` は「トリアージが完了した」と誤認する。結果として、修正プランの判定が未確定のまま `cc-fix-onetime` が付かず、`fix-review-point` ワーカーへの引き継ぎが空振りしたり、マージ判定前にラベルが外れて PR が放置される、といった状態壊れが発生する。ワーカー連携の同期性を担保するため、本スキルの内部処理はすべて同期実行で完結させる必要がある。

## 実行内容

以下のステップでPRのトリアージを行ってください。

### ステップ1: コンフリクト検知とラベル付与

`gh pr status` でPRのstatus（mergeable / コンフリクト有無）を取得し、コンフリクトがあれば `cc-resolve-conflict` ラベルを付けるだけで終了する。このスキルではrebase・force-push・コンフリクトファイル編集は一切行わない（実際の解消は同ラベルをトリガーに `resolve-pr-conflict` 等の別スキルが拾って実行する）。

```bash
gh pr status
```

`gh pr status` の出力から `#$ARGUMENTS` の行を特定し、コンフリクト表示（"Conflict" / 衝突マーク等）があるかを判定する。`gh pr status` は現在のユーザーに関連するPR（作成者・レビュアー・assignee）のみ表示するため、対象PRが出力に含まれない場合はフォールバックとして以下で同じ情報を取得する。

```bash
gh pr view $ARGUMENTS --json mergeable -q .mergeable
```

返却値 `MERGEABLE` / `CONFLICTING` / `UNKNOWN` のうち `CONFLICTING` のときコンフリクトありと判定する。`UNKNOWN` の場合はGitHub側で判定中のため、少し待ってから再取得する（数秒のスリープ後に1回だけリトライし、それでも `UNKNOWN` ならコンフリクトなし扱いで先に進む）。

判定に応じて以下のように分岐する。

- **コンフリクトあり（`CONFLICTING`）**: `cc-resolve-conflict` ラベルを付与してこのスキルを終了する。ステップ2・ステップ3には進まない（コンフリクト解消前に修正プラン評価やマージを行っても意味がないため）

  ```bash
  gh pr edit $ARGUMENTS --add-label "cc-resolve-conflict"
  ```

- **コンフリクトなし（`MERGEABLE` または `UNKNOWN` のリトライ後も判定不能）**: ステップ2に進む

このステップで `Edit` / `Write` / `MultiEdit` / `NotebookEdit` などの編集ツールを呼び出さないこと。コンフリクト解消の実作業はすべて別スキル（`cc-resolve-conflict` ラベル経由）に委譲する。

### ステップ2: 修正プランの生成と評価（**判定のみ・実行禁止**）

`create-review-fix-plan` skillを用いてPRの修正プランを生成する。

**重要**: ここで取得するプランは「PRをマージ可能か」を判定するための材料に過ぎない。プランに含まれるタスクをこのスキル内で実装してはならない。プランを読んだ結果、対応すべき項目があると判断したら **コードに手を加えず** ステップ3のパターンA（ラベル付与）へ進むこと。

生成された修正プランの各項目を以下の評価基準に基づいて分析し、対応要否を判定する。判定は内部的な思考にとどめ、ファイルの編集・コマンドの実行は行わない（参照のための`Read`/`Grep`は許容）。

#### 対応すべき
- **バグ・正確性の問題**: ロジックエラー、不正な動作、欠落したエッジケース
- **セキュリティ脆弱性**: SQLインジェクション、XSS、認証バイパス、データ漏洩
- **破壊的変更**: APIコントラクト違反、マイグレーションなしの後方互換性の破壊
- **型安全性の違反**: TypeScript型エラー、ランタイム障害を引き起こす可能性のある安全でないキャスト
- **テスト失敗**: 壊れたテスト、新しいロジックに対する重要なテストカバレッジの欠如
- **Lintエラー**: パイプラインをブロックする違反
- **データ整合性リスク**: レースコンディション、重要なデータに対するバリデーションの欠如
- **CIがオールグリーンになっていない**: CIが失敗している

#### 対応不要の可能性あり
- **純粋なスタイル好み**: コードベースパターンと一貫性のあるフォーマット選択
- **主観的な命名提案**: 既存の名前が明確で規約に従っている場合
- **過剰設計の提案**: まだ必要のないコードに対する抽象化の追加
- **スコープクリープ**: PR範囲外の無関係なコードのリファクタリングや機能追加の提案
- **既存パターンとの冗長**: 確立されたコードベース規約と矛盾する提案
- **非クリティカルパスへの指摘**: 正確性や保守性に影響しない軽微な改善

### ステップ3: 判定に基づくアクション

評価結果に基づき、以下の2パターンで判定し、**必ずどちらかのアクションを実行**する。判定のみで終了せず、コマンドの実行まで確実に行う。

#### パターンA: 修正が必要な場合

「対応すべき」と判定された項目が1つでもある場合、以下のコマンドを実行してPRに`cc-fix-onetime`ラベルを追加する。**ラベル付与のみで終了し、コード修正は行わない**（実際の修正は`cc-fix-onetime`ラベルをトリガーに別スキルが担当する）。

```
gh pr edit $ARGUMENTS --add-label "cc-fix-onetime"
```

ラベル付与後はこのスキルの責務は完了。たとえ修正項目が明確で実装が容易に見えても、ここでコード変更・コミット・pushを行ってはならない。

#### パターンB: マージ可能な場合

すべての項目が「対応不要」、または修正プランに項目がない場合、**必ず以下のコマンドを実行してマージする。判定だけで終了しないこと。**

```
gh pr merge $ARGUMENTS --merge --delete-branch
```

マージコマンドが失敗した場合は、エラー内容を記録して報告する。

## 意思決定の原則

1. **正確性はスタイルに優先**: 機能的な正確性を常に優先する
2. **レビュアーの意図を尊重**: 具体的な提案を却下する場合でも、レビュアーが達成しようとしていることを理解する
3. **コードベースの一貫性**: プロジェクトで確立されたパターンを優先する
4. **実用主義**: 各変更のコスト対効果を考慮する
5. **判断に迷う場合は対応すべきに寄せる**

## PRクローズ時のIssue連動Close

何かしらの理由で`gh pr close`によりPRをクローズする場合、必ず関連するIssueも併せてCloseすること。GitHubはPRが**マージされず**にCloseされた場合、`Closes #<issue番号>`記法で紐づいたIssueを自動Closeしないため、明示的にCloseする必要がある。

手順:

1. PRのdescriptionから関連Issueの番号を取得する。

```
gh pr view $ARGUMENTS --json body --jq '.body' | grep -ioE '(close[sd]?|fix(e[sd])?|resolve[sd]?)[[:space:]]+#[0-9]+' | grep -oE '[0-9]+'
```

2. PRをCloseする。

```
gh pr close $ARGUMENTS --delete-branch
```

3. 取得したIssue番号それぞれに対してCloseを実行する（複数ある場合は全て）。

```
gh issue close <issue番号> --reason "not planned"
```

関連Issueが取得できない場合は、その旨を報告に含めること。

## 注意事項

- 作業は全てworktree上で行い、デフォルトブランチで作業は絶対に行わないこと
- ファイル編集などの作業を行う際は、pwdコマンドでworktree内部であることを確認してから行うこと
  - 作業ディレクトリ: !`pwd`
- `cc-triage-scope`ラベルがPRに付与されている場合、いかなる操作においても**絶対に削除しない**こと
- `gh pr edit`で`--remove-label`を使用する際は`cc-triage-scope`を対象に含めないこと
- **このスキル本文では一切コードを変更しない**。コンフリクトの解消もこのスキルでは行わず、`cc-resolve-conflict`ラベルを付与して別スキル（`resolve-pr-conflict`等）に委ねる。ステップ2以降でEdit/Write/MultiEdit/NotebookEdit等の編集ツールを呼び出さないこと。プラン上で明らかな問題を見つけても、修正は別スキル（`cc-fix-onetime`ラベル経由の`fix-review-point`等）に委譲する

## 出力

処理結果として以下を報告する：

- **判定**: コンフリクト検知（`cc-resolve-conflict`ラベル付与） / パターンA（修正が必要・`cc-fix-onetime`ラベル付与） / パターンB（マージ済み） / PRクローズ（関連IssueもClose） / エラー
- **理由**: 判定の根拠（コンフリクト検知時はターゲットブランチ名、対応すべき項目の要約、マージ可能と判断した理由、またはクローズ理由と連動Closeした関連Issue番号）
