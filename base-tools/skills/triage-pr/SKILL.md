---
name: triage-pr
description: Triage a single GitHub PR by PR number. Check out the PR's branch, resolve conflicts with main, generate and evaluate a fix plan via create-review-fix-plan, then take action (add cc-fix-onetime label if fixes are needed, or merge the PR if it's ready).
argument-hint: "[pr-number]"
model: sonnet
effort: high
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

# Instructions

!`git fetch -p >/dev/null 2>&1`
!`gh pr checkout $ARGUMENTS >/dev/null 2>&1`

## 実行内容

以下のステップでPRのトリアージを行ってください。

### ステップ1: コンフリクト確認と解消

originのベースブランチとコンフリクトしていないか確認する。

```
git merge-tree $(git merge-base HEAD origin/main) HEAD origin/main
```

コンフリクトが検出された場合は、rebaseしてコンフリクトを解消する。

```
git rebase origin/main
```

rebase中にコンフリクトが発生した場合は、コンフリクトを解消し、`git rebase --continue`で続行する。rebase完了後、force-pushする。

```
git push origin HEAD --force-with-lease
```

コンフリクトの解消を行なった場合はステップ3には進まずこれで終了する。

### ステップ2: 修正プランの生成と評価

`create-review-fix-plan` skillを用いてPRの修正プランを生成する。

生成された修正プランの各項目を以下の評価基準に基づいて分析し、対応要否を判定する。

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

「対応すべき」と判定された項目が1つでもある場合、以下のコマンドを実行してPRに`cc-fix-onetime`ラベルを追加する。

```
gh pr edit $ARGUMENTS --add-label "cc-fix-onetime"
```

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

## 注意事項

- 作業は全てworktree上で行い、mainブランチで作業は絶対に行わないこと
- ファイル編集などの作業を行う際は、pwdコマンドでworktree内部であることを確認してから行うこと
  - 作業ディレクトリ: !`pwd`
- `cc-triage-scope`ラベルがPRに付与されている場合、いかなる操作においても**絶対に削除しない**こと
- `gh pr edit`で`--remove-label`を使用する際は`cc-triage-scope`を対象に含めないこと

## 出力

処理結果として以下を報告する：

- **判定**: パターンA（修正が必要） / パターンB（マージ済み） / エラー
- **理由**: 判定の根拠（対応すべき項目の要約、またはマージ可能と判断した理由）
