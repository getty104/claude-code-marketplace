---
name: edit-pencil-design
description: Pencil CLI（`pencil`コマンド）だけを使って既存の.penファイル（Pencilで作成されたデザインファイル）をAIプロンプトで修正・更新するスキル。ユーザーが.penファイルの編集、ボタン追加、レイアウト変更、UIデザインの調整、Pencilデザインの更新などを依頼した場合に必ずこのスキルを使用する。エージェントモード（`pencil --in --out --prompt`）で同一パスを指定して既存ファイルを上書き編集し、編集後はインタラクティブモード（`pencil interactive`）でNodeツリーから「**編集したコンポーネントのNodeだけ**」を特定して`get_screenshot` / `export_nodes` でPNG出力し、`.pen`と同階層の`snapshots/`ディレクトリに保存する。Pencil MCPには依存せず、`pencil` コマンドのみで完結する。
---

# Edit Pencil Design

このスキルは、Pencil CLI（`pencil`コマンド）**のみ**で `.pen` デザインファイルをAI編集し、編集Nodeだけのスクリーンショットを残すためのスキルです。MCPサーバーには依存しません。公式ドキュメント: [docs.pencil.dev/for-developers/pencil-cli](https://docs.pencil.dev/for-developers/pencil-cli)。

# 設計思想

Pencil CLI には2つの実行モードがあり、それぞれ役割が分かれています:

| モード | 起動方法 | できること |
|---|---|---|
| **エージェントモード** | `pencil --in --out --prompt` | AIプロンプトで `.pen` を編集（プロンプトによる編集はこのモード**のみ**） |
| **インタラクティブモード** | `pencil interactive -i -o` | `get_editor_state()` / `get_screenshot()` / `export_nodes()` / `save()` / `exit()` などのツール呼び出し（AIプロンプト編集機能は無い） |

つまり「AIで編集」「Node単位スクリーンショット」は**別モードで別に呼び出す**必要があります。これがこのスキルの基本構造です。

`.pen` は暗号化バイナリで `Read` / `Grep` では中身が見えないため、Node構造の確認・Node ID取得・Node単位スクリーンショットは全て `pencil interactive` 経由で行います。

# 重要な前提

- **既存ファイルをその場で上書き更新する** 運用に最適化（別名出力は二重管理を生むため避ける）
- **スクリーンショットはファイル全体ではなく、編集対象のNodeだけを対象にする**（差分レビューが容易、画面全体の他要素への巻き込み確認も一目）
- **Pencil MCPには依存しない**。`pencil` コマンドだけで完結させる

# 前提条件の確認

1. `pencil` コマンドが利用可能か（`pencil version` で確認）
   - 未インストールなら `npm install -g @pencil.dev/cli` をユーザーに案内（Node.js 18以上必要）
2. 認証済みか（`pencil status` で確認）
   - 未認証なら `pencil login`、または `PENCIL_CLI_KEY` 環境変数を設定するよう案内
3. 対象の `.pen` ファイルが存在するか（編集対象なのでファイルが先に存在している必要がある）

# 実行ルール

## ルール1: エージェントモードで `--in` と `--out` には同じパスを指定する

既存ファイルを更新する用途なので、必ず `--in` と `--out` に**同じ `.pen` ファイルのパス**を指定します。

```bash
pencil --in path/to/design.pen --out path/to/design.pen --prompt "<修正内容>"
# 短縮形
pencil -i path/to/design.pen -o path/to/design.pen -p "<修正内容>"
```

新規作成を依頼された場合のみ例外で、`--in` を省略して `--out` に新しいパスを指定します。

## ルール2: インタラクティブモードを heredoc で非対話的に呼び出す

`pencil interactive` は本来対話シェルですが、標準入力からコマンドを流せば非対話的に実行できます。スクリプトから安定して呼び出すため、heredoc で固定のコマンド列を流します。

```bash
pencil interactive -i path/to/design.pen -o path/to/design.pen <<'EOF'
get_editor_state()
exit()
EOF
```

- `-i` と `-o` には**編集対象と同じ `.pen` パス**を指定（ヘッドレスモードでは `-o` が必須）
- `save()` を呼ばなければファイルへの変更は永続化されません（Nodeツリー取得・スクリーンショットのみなら `save()` 不要）
- `exit()` を最後に呼んでシェルを終了

**未確定な仕様**: 各ツールの完全な引数仕様（出力先パラメータ名など）は公式ドキュメントに記載がありません。実環境では `pencil interactive --help` および `pencil --help` でローカルの実装を確認し、引数名が想定と異なる場合は調整してください。

## ルール3: 同時実行で競合しない一時ディレクトリを毎回確保する

`pencil interactive` の標準出力（`get_editor_state()` の返却JSON等）や中間ログを保存するパスを固定にすると、同じ `.pen` を別ターミナルや別プロセスから同時に編集したときに**上書き衝突**が起きます。これを避けるため、ワークフロー開始時に `mktemp -d` で**実行ごとに一意なディレクトリ**を確保し、すべての中間ファイルをそこに置きます。

```bash
# 実行ごとに一意な作業ディレクトリを確保（例: /tmp/pencil-edit-AbC123/）
WORK_DIR="$(mktemp -d -t pencil-edit-XXXXXX)"

# 終了時に必ず後始末（途中で失敗しても消える）
trap 'rm -rf "$WORK_DIR"' EXIT
```

なぜ `mktemp -d` を使うか:
- ディレクトリ名がカーネル側で一意性保証されるため、同名ファイル（`before.json` 等）を内側に置いても他の実行と絶対に衝突しない
- ディレクトリごと一括削除できるので後始末が `rm -rf "$WORK_DIR"` の一行で済む
- PID やタイムスタンプを自分で組み立てるより取り違えリスクが低い

以降の `before.json` / `after.json` などの中間ファイルは**必ず `${WORK_DIR}` 配下**に置きます（`/tmp/before.json` のような固定パスは使わない）。

## ルール4: 編集の前後でNodeツリーを取得し、編集されたNodeを特定する

スクリーンショット対象を「編集したNodeだけ」に絞るため、編集前後で `get_editor_state()` を呼んでツリーを比較します。

手順:

1. **編集前のスナップショット取得**
   ```bash
   pencil interactive -i path/to/design.pen -o path/to/design.pen <<'EOF' > "${WORK_DIR}/before.json"
   get_editor_state()
   exit()
   EOF
   ```
   返却されたJSON/構造化テキストから、各Nodeの `id` と主要属性（type, name, geometry, content など）を `before` として保持します。

2. **編集（エージェントモード）**
   ```bash
   pencil --in path/to/design.pen --out path/to/design.pen --prompt "<具体的な指示>" \
     > "${WORK_DIR}/edit.log" 2>&1
   ```
   エージェントモードの標準出力・標準エラーも `${WORK_DIR}` 配下に流すことで、同時実行時のログ取り違えを防ぎます。

3. **編集後のスナップショット取得**
   ```bash
   pencil interactive -i path/to/design.pen -o path/to/design.pen <<'EOF' > "${WORK_DIR}/after.json"
   get_editor_state()
   exit()
   EOF
   ```

4. **編集Nodeの特定**
   - `after` にあって `before` に無い `id` → **新規追加Node**
   - 双方にあるが属性差分のある `id` → **変更Node**
   - 上記の和集合が「編集したNodeの集合」

判定が難しい場合（idが再採番される、大規模な再構成など）は推定できる範囲で抽出し、残りはユーザーに確認します。フォールバックとして「最上位の影響を受けたフレーム/コンポーネントのNode ID」を1つ選んでスクリーンショットを取ります。

## ルール5: 編集したNodeだけをスクリーンショットし `snapshots/` に保存する

`.pen` ファイルと同じディレクトリ配下の `snapshots/` ディレクトリに、`pencil interactive` の `get_screenshot` / `export_nodes` でNode単位PNG出力します。

```bash
mkdir -p "$(dirname path/to/design.pen)/snapshots"
```

複数Nodeまとめて出すなら `export_nodes`、単一Nodeなら `get_screenshot` が自然です。引数名（出力先パラメータ・スケール等）はドキュメント未記載のため、まず以下の形を試し、エラーになったら `pencil interactive --help` で正しい引数名に置き換えてください。

```bash
pencil interactive -i path/to/design.pen -o path/to/design.pen <<'EOF'
export_nodes({
  nodes: [
    { id: "<編集Node1 ID>", out: "path/to/snapshots/design-<node1-name>-<timestamp>.png", format: "png", scale: 2 },
    { id: "<編集Node2 ID>", out: "path/to/snapshots/design-<node2-name>-<timestamp>.png", format: "png", scale: 2 }
  ]
})
exit()
EOF
```

単一Nodeなら:

```bash
pencil interactive -i path/to/design.pen -o path/to/design.pen <<'EOF'
get_screenshot({ nodeId: "<編集Node ID>", out: "path/to/snapshots/design-<node>-<timestamp>.png", scale: 2 })
exit()
EOF
```

ファイル命名規則の推奨:
- `<.penファイル名のステム>-<Node名 or Node ID短縮>-<YYYYMMDD-HHMMSS>.png`
- 例: `login.pen` の `header` Nodeを編集 → `snapshots/login-header-20260627-153045.png`

**ファイル全体のエクスポート（エージェントモードの `--export`）は原則使いません。** ユーザーから明示的にファイル全体画像を要求された場合のみ、補助的に `pencil --in <path> --export <全体画像のpath> --export-scale 2` を追加します。

## ルール6: 実行結果をユーザーに伝える

`.pen` の中身は直接確認できないため、ユーザーへの最終報告には以下を必ず含めます。

- 実行したコマンド（エージェントモードのCLIと、インタラクティブモードのheredoc）
- 編集したと判定したNode（IDと、可能なら名前・type）
- 更新した `.pen` ファイルの絶対パス
- 出力したNode単位スクリーンショット画像の絶対パス（編集Nodeごと）

# 標準ワークフロー

ユーザーから「`xxx.pen` の〇〇を編集して」のような依頼を受けたときの標準フローです。

1. **前提確認**: `pencil version`、`pencil status`
2. **対象ファイル確認**: 指定された `.pen` ファイルが存在するか
3. **作業ディレクトリ確保**: `WORK_DIR="$(mktemp -d -t pencil-edit-XXXXXX)"` と `trap 'rm -rf "$WORK_DIR"' EXIT` を設定（同時実行衝突回避）
4. **`snapshots/` ディレクトリ準備**: `mkdir -p <.penと同じディレクトリ>/snapshots`
5. **編集前スナップショット**: `pencil interactive` のheredocで `get_editor_state()` を呼び `${WORK_DIR}/before.json` に保存
6. **編集実行**: `pencil --in <path> --out <path> --prompt "<指示>" > "${WORK_DIR}/edit.log" 2>&1`（`--in`/`--out`は同一パス）
7. **編集後スナップショット**: `pencil interactive` のheredocで `get_editor_state()` を呼び `${WORK_DIR}/after.json` に保存
8. **編集Node特定**: `${WORK_DIR}/before.json` と `${WORK_DIR}/after.json` の差分から新規/変更されたNode IDを抽出
9. **Node単位スクリーンショット**: `pencil interactive` のheredocで `export_nodes` または `get_screenshot` を呼び、`snapshots/` 配下にPNG出力（出力先パスはタイムスタンプ込みのファイル名にすることで `snapshots/` 内も同時実行で衝突しない）
10. **報告**: 編集Nodeと出力画像パスをユーザーへ提示（`trap` により `${WORK_DIR}` は自動削除される）

# 使用例

## 例1: ログインページに「Forgot password?」リンクを追加

```bash
pencil status
mkdir -p designs/snapshots

# 0) 実行ごとに一意な作業ディレクトリ（同時実行衝突回避）
WORK_DIR="$(mktemp -d -t pencil-edit-XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

# 1) 編集前 Nodeツリー
pencil interactive -i designs/login.pen -o designs/login.pen <<'EOF' > "${WORK_DIR}/before.json"
get_editor_state()
exit()
EOF

# 2) 編集（エージェントモード、--in と --out は同じファイル）
pencil \
  --in designs/login.pen \
  --out designs/login.pen \
  --prompt "Add a 'Forgot password?' link below the password input, aligned to the right" \
  > "${WORK_DIR}/edit.log" 2>&1

# 3) 編集後 Nodeツリー
pencil interactive -i designs/login.pen -o designs/login.pen <<'EOF' > "${WORK_DIR}/after.json"
get_editor_state()
exit()
EOF
```

`${WORK_DIR}/before.json` と `${WORK_DIR}/after.json` を比較し、新規Node `forgot-link-01` を特定した上で（`snapshots/` 内のファイル名にも `$(date +%Y%m%d-%H%M%S)` を埋め込み、複数実行が同時に永続成果物を残しても衝突しないようにします）:

```bash
TS="$(date +%Y%m%d-%H%M%S)"
pencil interactive -i designs/login.pen -o designs/login.pen <<EOF
get_screenshot({ nodeId: "forgot-link-01", out: "designs/snapshots/login-forgot-link-${TS}.png", scale: 2 })
exit()
EOF
```

## 例2: ダッシュボードのサイドバーに2件のメニュー項目を追加

```bash
mkdir -p src/designs/snapshots

WORK_DIR="$(mktemp -d -t pencil-edit-XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

# 編集前
pencil interactive -i src/designs/dashboard.pen -o src/designs/dashboard.pen <<'EOF' > "${WORK_DIR}/before.json"
get_editor_state()
exit()
EOF

# 編集
pencil \
  -i src/designs/dashboard.pen \
  -o src/designs/dashboard.pen \
  -p "サイドバーに 'Reports' と 'Billing' のメニュー項目を追加し、Settings の上に配置する" \
  > "${WORK_DIR}/edit.log" 2>&1

# 編集後
pencil interactive -i src/designs/dashboard.pen -o src/designs/dashboard.pen <<'EOF' > "${WORK_DIR}/after.json"
get_editor_state()
exit()
EOF
```

差分で `reports-item` と `billing-item` の2つを編集Nodeと判定:

```bash
TS="$(date +%Y%m%d-%H%M%S)"
pencil interactive -i src/designs/dashboard.pen -o src/designs/dashboard.pen <<EOF
export_nodes({
  nodes: [
    { id: "reports-item", out: "src/designs/snapshots/dashboard-reports-item-${TS}.png", format: "png", scale: 2 },
    { id: "billing-item", out: "src/designs/snapshots/dashboard-billing-item-${TS}.png", format: "png", scale: 2 }
  ]
})
exit()
EOF
```

新規Nodeが親コンテナ（サイドバー）の中に追加された場合、親のサイドバーNode IDも対象に加えると配置確認しやすくなります。

## 例3: 軽量モデルで小修正

```bash
WORK_DIR="$(mktemp -d -t pencil-edit-XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

pencil \
  --in designs/error-404.pen \
  --out designs/error-404.pen \
  --model claude-haiku-4-5 \
  --prompt "Change the heading text to 'ページが見つかりません'" \
  > "${WORK_DIR}/edit.log" 2>&1
```

heading Nodeのidを before/after 比較（`${WORK_DIR}/before.json` / `${WORK_DIR}/after.json`）で特定したあと:

```bash
TS="$(date +%Y%m%d-%H%M%S)"
pencil interactive -i designs/error-404.pen -o designs/error-404.pen <<EOF
get_screenshot({ nodeId: "<heading-node-id>", out: "designs/snapshots/error-404-heading-${TS}.png", scale: 2 })
exit()
EOF
```

# 主要オプション/コマンド早見表

## エージェントモード（編集用）

| オプション | 短縮 | 用途 |
|---|---|---|
| `--in <path>` | `-i` | 入力 `.pen` ファイル（編集元） |
| `--out <path>` | `-o` | 出力 `.pen` ファイル（編集先、`--in` と同じパスを指定する） |
| `--prompt <text>` | `-p` | AI エージェントへの編集指示 |
| `--model <id>` | - | 使用モデル指定（`claude-opus-4-6` / `claude-sonnet-4-6` / `claude-haiku-4-5`） |
| `--export <path>` | - | ファイル全体の画像出力（本スキルでは原則使わない） |
| `--export-scale <n>` | - | エクスポート時のスケール（同上） |

## インタラクティブモード（Node取得・スクショ用）

| 起動オプション | 用途 |
|---|---|
| `--in / -i <path>` | 入力 `.pen` ファイル |
| `--out / -o <path>` | 出力 `.pen` ファイル（ヘッドレス時必須） |
| `--app / -a <name>` | 実行中のPencilアプリに接続 |
| `--help / -h` | ツールリファレンスを表示 |

シェル内ツール:
- `get_editor_state()` — Nodeツリーやメタデータの取得
- `get_screenshot(...)` — 単一NodeをPNGレンダリング
- `export_nodes(...)` — 複数NodeをPNG/JPEG/WEBP/PDFへエクスポート
- `snapshot_layout(...)` — レイアウトのスナップショット
- `batch_get(...)` / `batch_design(...)` — 複雑な取得/編集の一括処理
- `get_variables()` — 変数の取得
- `get_guidelines()` — ガイドラインの取得
- `save()` — 編集結果を `.pen` に書き出す（読み取り目的の呼び出しでは省略）
- `exit()` — シェル終了

# トラブルシューティング

- **`pencil: command not found`**: `npm install -g @pencil.dev/cli` を案内（Node.js 18以上必要）
- **認証エラー**: `pencil login` で対話ログイン、または `PENCIL_CLI_KEY` 環境変数を設定するよう案内
- **`pencil interactive` で `-o` が必須エラー**: ヘッドレス実行では `-o` が必要。読み取り目的でも `-i` と同じパスを `-o` に指定し、`save()` を呼ばないことで変更は永続化されない
- **`get_screenshot` / `export_nodes` の引数名エラー**: 出力先パラメータ名（`out` / `path` / `output` 等）や `scale` / `format` などはドキュメント未記載。`pencil interactive --help` でローカルの実装を確認し、引数名を合わせる
- **編集Nodeが特定できない（idが再採番される/大規模変更）**: 影響を受けた最上位フレーム/コンポーネントのNodeを代表として1つエクスポートし、ユーザーに確認を求める
- **`.pen` ファイルが見つからない**: パスを再確認。新規作成希望なら `--in` を省略して別途新規作成
- **想定と違う編集結果**: `--prompt` をより具体的に書き直して再実行。`.pen` は上書きされるため、重要な編集前にはユーザーに git コミット等のバックアップを促す
