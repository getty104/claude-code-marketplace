---
name: check-dependabot
description: 指定されたPR番号のDependabot PRを確認し、依存ライブラリのバージョンアップ内容をCHANGELOGとcontext7から取得して、コード修正が必要かを判定します。修正が必要な場合は修正を行い、pushまで実施します。
argument-hint: "[pr-number]"
hooks:
  Stop:
    - matcher: ""
      hooks:
        - type: command
          command: docker compose down --volumes --remove-orphans
---

# Check Dependabot

Dependabotによって作成されたPRに対して、依存ライブラリのバージョンアップに伴う破壊的変更や注意点を確認し、既存コードへの影響有無を判定・修正するためのスキルです。
このスキルが呼び出された際には、Instructionsに従って、対象PRの情報を取得し、バージョン差分の分析とコード修正を行ってください。

# Instructions

!`git fetch origin main >/dev/null 2>&1`
!`gh pr checkout $ARGUMENTS >/dev/null 2>&1`

## 実行内容

以下のステップでDependabot PRの確認と対応を行ってください。

### ステップ1: 対象PR情報の取得

PR番号からPR情報を取得する。

```
gh pr view $ARGUMENTS --json number,title,body,headRefName
```

取得したPRのタイトル・bodyから以下の情報を抽出する。

- **ライブラリ名（パッケージ名）**
- **変更前のバージョン（from）**
- **変更後のバージョン（to）**
- **エコシステム**（npm / pip / go modules / GitHub Actions など）

Dependabotの標準タイトル形式: `Bump <package> from <old-version> to <new-version>`

複数パッケージの更新（grouped update）の場合は、PR bodyから各パッケージの更新情報を全て抽出する。

### ステップ2: 変更差分の取得

対象ライブラリの変更差分を、以下の優先順位で取得する。

#### 2-1. PR bodyのrelease notes / changelog

Dependabot PRのbodyには、多くの場合リリースノートとchangelogのサマリーが含まれている。まずはこれを確認する。

#### 2-2. CHANGELOG / Release Notes（GitHub）

PRのbodyに十分な情報がない、または破壊的変更の詳細確認が必要な場合は、GitHub上のCHANGELOGやReleasesを直接取得する。

```
# リポジトリが分かる場合
gh api repos/<owner>/<repo>/releases --jq '.[] | select(.tag_name >= "<from>" and .tag_name <= "<to>") | {tag_name, body}'

# CHANGELOGファイルを直接取得
gh api repos/<owner>/<repo>/contents/CHANGELOG.md --jq '.content' | base64 -d
```

#### 2-3. context7 MCP

上記で十分な情報が得られない場合、または公式ドキュメント上のマイグレーションガイドを確認したい場合は、context7 MCPを使用する。

```
# ライブラリIDの解決
mcp__plugin_base-tools_context7__resolve-library-id
  libraryName: "<ライブラリ名>"

# マイグレーションガイドや破壊的変更に関するドキュメント取得
mcp__plugin_base-tools_context7__query-docs
  context7CompatibleLibraryID: "<resolve-library-idで取得したID>"
  topic: "migration breaking changes <from> to <to>"
```

### ステップ3: 影響範囲の分析

取得した変更差分をもとに、以下の観点でリポジトリ内のコードへの影響を確認する。

#### 確認すべき項目
- **破壊的変更（Breaking Changes）**: 削除・リネームされたAPI、シグネチャ変更、挙動変更
- **非推奨化（Deprecations）**: 警告対象のAPI使用箇所
- **デフォルト値の変更**: 設定値やオプションのデフォルト変更
- **ピア依存関係の変更**: peerDependenciesやminimum version要件の変更
- **型定義の変更**: TypeScriptの型変更による型エラーの可能性

#### 調査方法

破壊的変更や非推奨APIがある場合、Grepで該当APIの使用箇所を検索する。

```
# 例: 変更されたAPIの使用箇所を検索
```

Grepツールで対象のシンボル・関数・設定名を検索し、使用箇所があるかを確認する。

### ステップ4: CIステータスの確認

PRのCIステータスを取得し、判定材料にする。

```
gh pr checks $ARGUMENTS
```

- **全てpass**: そのままステップ5の判定へ進む
- **fail / pending がある**: failしているチェックの内容（ログ）を確認し、原因がバージョンアップに起因するものかを判断する
  - バージョンアップ起因のfail: ステップ5でパターンA（修正）に進む
  - バージョンアップと無関係なfail（flaky、外部要因など）: その旨を報告し、マージはせず処理を終了する
  - pending: 完了を待ってから再確認する

### ステップ5: 修正要否の判定

以下の基準で判定する。

#### 修正が必要
- 破壊的変更の影響を受けるコードがリポジトリ内に存在する
- 型エラー・ビルドエラー・テスト失敗を引き起こす変更がある
- 非推奨APIの使用でCIがfailする可能性がある
- デフォルト値の変更により既存の挙動が変わる
- CIチェックがバージョンアップ起因でfailしている

#### 修正不要
- 影響を受けるコードがリポジトリ内に存在しない
- パッチ/マイナーアップデートで破壊的変更なし
- 変更内容が内部実装のみで公開APIに影響なし
- CIチェックが全てpassしている

### ステップ6: 修正の実施とpush

#### パターンA: 修正が必要な場合

1. 該当箇所をマイグレーションガイドに従って修正する
2. 必要に応じてビルド・Lint・型チェック・テストを実行して修正の妥当性を確認する
3. `commit-push` skillを用いてコミットとpushを行う

#### パターンB: 修正不要の場合

追加のコミットは行わず、**CIチェックが全てpassしていることを再確認した上で**、以下のコマンドでPRをマージする。**判定だけで終了せず、必ずマージコマンドを実行すること。**

```
gh pr merge $ARGUMENTS --merge --delete-branch
```

マージコマンドが失敗した場合は、エラー内容を記録して報告する。CIがpassしていない場合はマージを実行せず、状況を報告する。

#### パターンC: マージ不可能の場合
対象のバージョンはマージすることができない・するべきではないと判断する場合、PRをクローズする
マージをすることができない場合の例は以下の通り。

- 依存しているライブラリが最新のバージョンに対応していない
- 最新のバージョンにすることで、サービスの挙動が変わってしまう

## 注意事項

- 作業は必ず対象ブランチ上で行い、mainブランチで作業は絶対に行わないこと
- ファイル編集などの作業を行う際は、pwdコマンドで現在のディレクトリを確認してから行うこと
  - 作業ディレクトリ: !`pwd`
- 複数パッケージを含むgrouped updateの場合は、すべてのパッケージについて個別に影響分析を行うこと
- Dependabot以外が作成したPRには使用しないこと

## 出力

処理結果として以下を報告する：

- **対象PR**: PR番号とタイトル
- **対象ライブラリ**: ライブラリ名とバージョン（from → to）
- **破壊的変更の有無**: あり / なし（概要）
- **CIステータス**: 全pass / fail（原因） / pending
- **判定**: パターンA（修正あり） / パターンB（マージ済み） / エラー
- **修正内容**: 修正した場合はその内容（パターンAのみ）
