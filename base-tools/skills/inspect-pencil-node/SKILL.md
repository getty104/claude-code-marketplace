---
name: inspect-pencil-node
description: Pencil CLI（`pencil`コマンド）だけを使って、特定の.penファイル（Pencilで作成されたデザインファイル）の中の指定したNodeのデザインデータ（属性・構造）とスクリーンショット画像をペアで取得する読み取り専用スキル。ユーザーが「.penのこのNodeの中身を見せて」「特定コンポーネントのデザインデータを取り出して」「Nodeのスクリーンショットだけ欲しい」「ヘッダーの構造を確認したい」「ボタンのスタイルをコピーしたい」「Pencilで作ったあのNodeのプロパティを教えて」のように.pen内の特定要素の調査・参照・確認・抜き出しを依頼した場合に必ずこのスキルを使う。インタラクティブモード（`pencil interactive`）で `batch_get` を使ってNode属性をJSONで取得し、`get_screenshot` で画像を`.pen`と同階層の`snapshots/`にPNG出力する。編集はしない（`save()`を呼ばない）ため、対象ファイルは絶対に書き換わらない。Pencil MCPには依存せず`pencil`コマンドのみで完結。
---

# Inspect Pencil Node

このスキルは、Pencil CLI（`pencil`コマンド）**のみ**で `.pen` デザインファイル内の特定Nodeのデータと画像を**読み取り専用**で取得するスキルです。MCPサーバーには依存しません。公式ドキュメント: [docs.pencil.dev/for-developers/pencil-cli](https://docs.pencil.dev/for-developers/pencil-cli)。

姉妹スキル `edit-pencil-design` が「編集 + 編集Nodeのスクショ」を担当するのに対し、こちらは「**特定Nodeを覗き見るだけ**」を担当します。`.pen` の中身は一切書き換えません。

# 設計思想

Pencil CLI には2つの実行モードがあります:

| モード | 起動方法 | このスキルでの用途 |
|---|---|---|
| エージェントモード | `pencil --in --out --prompt` | **使わない**（AI編集モードなので読み取り目的では不要） |
| **インタラクティブモード** | `pencil interactive -i -o` | このスキルの中核。`batch_get` / `get_screenshot` / `get_editor_state` / `exit` を heredoc で呼ぶ |

`.pen` は暗号化バイナリで `Read` / `Grep` では中身が見えないため、Node属性の取得・スクリーンショット出力はすべてインタラクティブモード経由で行います。

# 重要な前提

- **完全な読み取り専用**。インタラクティブシェルで `save()` を呼ばないことで、Nodeを覗いても `.pen` ファイル自体は1バイトも変更されません
- **取得対象はNode単位**。ファイル全体ではなく、ユーザーが指定したNode（または推定したNode）に絞ってデータと画像を返します
- **Pencil MCPには依存しない**。`pencil` コマンドだけで完結

# 前提条件の確認

1. `pencil` コマンドが利用可能か（`pencil version` で確認）
   - 未インストールなら `npm install -g @pencil.dev/cli` をユーザーに案内（Node.js 18以上必要）
2. 認証済みか（`pencil status` で確認）
   - 未認証なら `pencil login`、または `PENCIL_CLI_KEY` 環境変数を設定するよう案内
3. 対象の `.pen` ファイルが存在するか
4. ユーザーが Node ID を指定しているか
   - 未指定なら `get_editor_state()` でNodeツリーを取り、候補をユーザーに提示して選んでもらう

# 実行ルール

## ルール1: 読み取り目的では `save()` を絶対に呼ばない

`pencil interactive` のヘッドレス実行では `-o` の指定が必須なので、入力と同じパスを `-o` に渡します。**ただし `save()` を呼ばない限りディスクへの書き込みは発生しません**。これがファイル不変性の担保です。heredocの末尾は必ず `exit()` で締めます。

```bash
pencil interactive -i path/to/design.pen -o path/to/design.pen <<'EOF'
batch_get({ nodeIds: ["<node-id>"] })
exit()
EOF
```

`save()` を入れないことが「読み取り専用」を保証する唯一の手段なので、ここは強く意識します。

## ルール2: インタラクティブモードを heredoc で非対話的に呼び出す

スクリプトから安定して呼ぶため、heredoc で固定のコマンド列を流します。

```bash
pencil interactive -i path/to/design.pen -o path/to/design.pen <<'EOF' > "${WORK_DIR}/out.json"
batch_get({ nodeIds: ["<node-id>"] })
exit()
EOF
```

**未確定な仕様**: 各シェル内ツール（`batch_get` / `get_screenshot` 等）の完全な引数仕様（出力先パラメータ名、scale、padding 等）は公式ドキュメントに記載がありません。実環境では `pencil interactive --help` でローカル実装を確認し、引数名が想定と異なる場合は調整してください。

## ルール3: 同時実行で競合しない一時ディレクトリを毎回確保する

`batch_get` の返却JSONなど中間ファイルの保存先を固定にすると、同じ `.pen` を別ターミナル・別プロセスから同時に inspect したときに上書き衝突が起きます。ワークフロー開始時に `mktemp -d` で実行ごとに一意なディレクトリを確保し、すべての中間ファイルをそこに置きます。

```bash
WORK_DIR="$(mktemp -d -t pencil-inspect-XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT
```

なぜ `mktemp -d` か:
- ディレクトリ名がカーネル側で一意性保証されるため、同名ファイル（`out.json`等）を内側に置いても他実行と絶対に衝突しない
- `trap 'rm -rf "$WORK_DIR"' EXIT` で途中失敗時も自動後始末
- PIDやタイムスタンプを自分で組み立てるより取り違えリスクが低い

中間JSON（`batch_get` 結果や `get_editor_state` 結果）は必ず `${WORK_DIR}` 配下に置き、`/tmp/out.json` のような固定パスは使いません。

## ルール4: 対象Nodeの決定

ユーザーが既にNode IDを指定している場合はそのまま使います。指定がない場合や、名前ベース（「ヘッダー」「ログインボタン」など）でしか分かっていない場合は、まず `get_editor_state()` でNodeツリーを取り、候補IDをユーザーに提示します。

```bash
pencil interactive -i path/to/design.pen -o path/to/design.pen <<'EOF' > "${WORK_DIR}/tree.json"
get_editor_state()
exit()
EOF
```

返却JSONから type / name / id を抽出し、ユーザーの言葉に合うNodeを推定。曖昧な場合は3〜5件提示して選ばせる。確定したNode IDを以降のステップで使います。

## ルール5: `batch_get` でNode属性を取得する

`batch_get` は複数Nodeをまとめて取れるので、1Nodeでも複数Nodeでも同じ流儀で書けます。

```bash
pencil interactive -i path/to/design.pen -o path/to/design.pen <<EOF > "${WORK_DIR}/nodes.json"
batch_get({ nodeIds: [${NODE_IDS_JSON_LIST}] })
exit()
EOF
```

`${NODE_IDS_JSON_LIST}` は `"id1", "id2"` のようなカンマ区切りJSON文字列。`<<EOF`（クォートなし）にすることでbash変数を展開できます。

得られたJSONから、ユーザーへの報告で重要な属性（type / name / geometry / style / content / 子Nodeのid と name など）を要約します。生のJSON全体ではなく要点を整理して提示するのが親切です。フルダンプが必要なら `${WORK_DIR}/nodes.json` の絶対パスも併記します。

## ルール6: `get_screenshot` で画像を取得し `snapshots/` に保存する

画像は `.pen` ファイルと同じディレクトリ配下の `snapshots/` に保存します。同時実行や繰り返し inspect でファイル名が衝突しないよう、ファイル名にタイムスタンプを必ず含めます。

```bash
mkdir -p "$(dirname path/to/design.pen)/snapshots"
TS="$(date +%Y%m%d-%H%M%S)"

pencil interactive -i path/to/design.pen -o path/to/design.pen <<EOF
get_screenshot({ nodeId: "${NODE_ID}", out: "path/to/snapshots/<file>-<node>-${TS}.png", scale: 2 })
exit()
EOF
```

複数Node を一度に画像化したい場合は `export_nodes` を使うほうが効率的です。

```bash
pencil interactive -i path/to/design.pen -o path/to/design.pen <<EOF
export_nodes({
  nodes: [
    { id: "node-a", out: "path/to/snapshots/<file>-node-a-${TS}.png", format: "png", scale: 2 },
    { id: "node-b", out: "path/to/snapshots/<file>-node-b-${TS}.png", format: "png", scale: 2 }
  ]
})
exit()
EOF
```

ファイル命名規則の推奨: `<.penファイル名のステム>-<Node名 or Node ID短縮>-<YYYYMMDD-HHMMSS>.png`
- 例: `login.pen` の `header` Node → `snapshots/login-header-20260627-160500.png`

スケールは視認性のため `scale: 2` を推奨。引数名が想定と異なる場合は `pencil interactive --help` で実装を確認して合わせます。

## ルール7: データとスクリーンショットを同一heredocでまとめて取得してもよい

`batch_get` と `get_screenshot` は同じインタラクティブセッションで連続実行できます。標準出力に `batch_get` のJSONと `get_screenshot` の結果メッセージが混ざるため、両者の分離が容易な簡単なケースでは効率優先で1回にまとめ、複雑なケースでは別々に呼んで標準出力をきれいに切り分けるのが安全です。

両方まとめる例:

```bash
pencil interactive -i path/to/design.pen -o path/to/design.pen <<EOF > "${WORK_DIR}/combined.txt"
batch_get({ nodeIds: ["${NODE_ID}"] })
get_screenshot({ nodeId: "${NODE_ID}", out: "path/to/snapshots/<file>-<node>-${TS}.png", scale: 2 })
exit()
EOF
```

## ルール8: 実行結果をユーザーに伝える

`.pen` の中身は直接確認できないため、ユーザーへの最終報告には以下を含めます。

- 対象とした Node ID（と、可能なら name / type）
- Node属性の要約（type / name / geometry / 主要style / content / 子Nodeなど）
- 生データJSONの保存パス（`${WORK_DIR}` 配下 — セッション中のみ有効、後始末で消える）
- 出力したスクリーンショット画像の絶対パス（`.pen` と同階層の `snapshots/` に永続化）

ユーザーがJSONを永続的に手元に欲しがった場合は、`cp "${WORK_DIR}/nodes.json" <ユーザー希望パス>` で別途コピーすることを案内します。

# 標準ワークフロー

ユーザーから「`xxx.pen` の〇〇Nodeのデータと画像を取得して」のような依頼を受けたときの標準フロー。

1. **前提確認**: `pencil version`、`pencil status`、対象 `.pen` ファイルの存在
2. **作業ディレクトリ確保**: `WORK_DIR="$(mktemp -d -t pencil-inspect-XXXXXX)"` と `trap 'rm -rf "$WORK_DIR"' EXIT`
3. **`snapshots/` ディレクトリ準備**: `mkdir -p <.penと同じディレクトリ>/snapshots`
4. **Node ID 確定**: ユーザー指定があればそれを使う。なければ `get_editor_state()` でツリーを取り、候補を提示して選んでもらう
5. **属性取得**: heredoc で `batch_get({ nodeIds: [...] })` を呼び `${WORK_DIR}/nodes.json` に保存
6. **画像取得**: heredoc で `get_screenshot` または `export_nodes` を呼び、`snapshots/<file>-<node>-<timestamp>.png` に保存
7. **要約報告**: Node属性の要点と画像パスをユーザーに提示。フルダンプが必要なら `${WORK_DIR}/nodes.json` のパスも併記（`trap` でセッション終了時に消えることも一言添える）

# 使用例

## 例1: ログイン画面のヘッダーNodeを覗き見る

```bash
pencil status
mkdir -p designs/snapshots

WORK_DIR="$(mktemp -d -t pencil-inspect-XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

# Node ID が分からない → まずツリーを取る
pencil interactive -i designs/login.pen -o designs/login.pen <<'EOF' > "${WORK_DIR}/tree.json"
get_editor_state()
exit()
EOF
```

返却されたJSONから type=Frame, name="Header" のNode（仮に id="header-01"）を特定したあと:

```bash
TS="$(date +%Y%m%d-%H%M%S)"

# 属性 + 画像を1回のセッションで
pencil interactive -i designs/login.pen -o designs/login.pen <<EOF > "${WORK_DIR}/combined.txt"
batch_get({ nodeIds: ["header-01"] })
get_screenshot({ nodeId: "header-01", out: "designs/snapshots/login-header-${TS}.png", scale: 2 })
exit()
EOF
```

ユーザーへの報告:
- Node: `header-01` (type=Frame, name="Header")
- 主要属性: 幅 1280px / 高さ 64px / 背景色 #FFFFFF / 子要素: Logo, NavMenu, ProfileButton
- スクリーンショット: `designs/snapshots/login-header-20260627-160500.png`
- 生データJSON: `${WORK_DIR}/combined.txt`（セッション終了で削除されるため、必要なら別パスにコピー）

## 例2: ダッシュボードのカード3つを一度に取得

ユーザーが既に id=`card-revenue`, `card-users`, `card-mrr` の3つを欲しいと言っているケース。

```bash
mkdir -p src/designs/snapshots

WORK_DIR="$(mktemp -d -t pencil-inspect-XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

TS="$(date +%Y%m%d-%H%M%S)"

# 属性は1ファイルに
pencil interactive -i src/designs/dashboard.pen -o src/designs/dashboard.pen <<'EOF' > "${WORK_DIR}/cards.json"
batch_get({ nodeIds: ["card-revenue", "card-users", "card-mrr"] })
exit()
EOF

# 画像は3枚別ファイルに
pencil interactive -i src/designs/dashboard.pen -o src/designs/dashboard.pen <<EOF
export_nodes({
  nodes: [
    { id: "card-revenue", out: "src/designs/snapshots/dashboard-card-revenue-${TS}.png", format: "png", scale: 2 },
    { id: "card-users",   out: "src/designs/snapshots/dashboard-card-users-${TS}.png",   format: "png", scale: 2 },
    { id: "card-mrr",     out: "src/designs/snapshots/dashboard-card-mrr-${TS}.png",     format: "png", scale: 2 }
  ]
})
exit()
EOF
```

報告では3カードそれぞれの主要属性（テキスト、数値、配色）と3枚の画像パスを並べて提示します。

## 例3: 既存ボタンのスタイルをコピー目的で抜き出す

ユーザー: 「`marketing/cta.pen` の Primary CTA ボタンのスタイル教えて。新しいページに同じやつ作りたい」

```bash
mkdir -p marketing/snapshots

WORK_DIR="$(mktemp -d -t pencil-inspect-XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

# まずツリーから "Primary CTA" っぽい Node を探す
pencil interactive -i marketing/cta.pen -o marketing/cta.pen <<'EOF' > "${WORK_DIR}/tree.json"
get_editor_state()
exit()
EOF
```

ツリーから id=`btn-primary-cta` を特定:

```bash
TS="$(date +%Y%m%d-%H%M%S)"

pencil interactive -i marketing/cta.pen -o marketing/cta.pen <<EOF > "${WORK_DIR}/btn.json"
batch_get({ nodeIds: ["btn-primary-cta"] })
get_screenshot({ nodeId: "btn-primary-cta", out: "marketing/snapshots/cta-btn-primary-${TS}.png", scale: 2 })
exit()
EOF
```

報告では `fill`, `cornerRadius`, `padding`, `fontFamily`, `fontWeight`, `fontSize`, `textColor`, hover/active 状態など、再現に必要なスタイル属性を抜き出して提示します。

# 主要オプション/コマンド早見表

## インタラクティブモード起動オプション

| オプション | 用途 |
|---|---|
| `--in / -i <path>` | 入力 `.pen` ファイル |
| `--out / -o <path>` | 出力 `.pen` ファイル（ヘッドレス時必須。`save()`を呼ばないため書き換わらない） |
| `--app / -a <name>` | 実行中のPencilアプリに接続 |
| `--help / -h` | ツールリファレンスを表示 |

## シェル内ツール（このスキルで使う中心）

| ツール | 用途 |
|---|---|
| `get_editor_state()` | Nodeツリー・メタデータの取得（Node ID探索に使う） |
| `batch_get({ nodeIds: [...] })` | **指定NodeのデザインデータをまとめてJSONで取得**（本スキルの中核） |
| `get_screenshot({ nodeId: "...", out: "...", scale: 2 })` | **単一NodeをPNGレンダリング**（本スキルの中核） |
| `export_nodes({ nodes: [{id, out, format, scale}, ...] })` | 複数NodeをまとめてPNG/JPEG/WEBP/PDFへ出力 |
| `snapshot_layout(...)` | レイアウトのスナップショット（必要に応じて） |
| `get_variables()` | 変数の取得（参照に役立つ場合） |
| `exit()` | シェル終了（heredoc末尾に必ず置く） |
| `save()` | ディスクへ書き出し（**このスキルでは絶対に呼ばない**） |

# トラブルシューティング

- **`pencil: command not found`**: `npm install -g @pencil.dev/cli` を案内（Node.js 18以上必要）
- **認証エラー**: `pencil login` で対話ログイン、または `PENCIL_CLI_KEY` 環境変数を設定するよう案内
- **`pencil interactive` で `-o` が必須エラー**: ヘッドレス実行では `-o` 必須。入力と同じパスを `-o` に指定し、`save()` を呼ばないことで変更は永続化されない
- **`batch_get` / `get_screenshot` の引数名エラー**: 出力先パラメータ名（`out` / `path` / `output` 等）や `scale` / `format` などはドキュメント未記載。`pencil interactive --help` でローカル実装を確認し引数名を合わせる
- **Node ID が分からない**: `get_editor_state()` でツリー取得→候補をユーザーに提示。ユーザーの言葉（「ヘッダー」「ログインボタン」など）から type / name で推定
- **`.pen` ファイルが見つからない**: パスを再確認
- **大きいNodeで画像取得が遅い/タイムアウト**: `scale` を 1 に下げて再試行。それでも遅ければ親ではなく子Nodeに絞って取得
- **誤ってファイルを書き換えてしまった気がする**: このスキルは `save()` を呼ばないので原則変わらない。心配な場合は git で diff 確認、もしくは事前に `git status` で対象ファイルが clean であることを確認しておく
