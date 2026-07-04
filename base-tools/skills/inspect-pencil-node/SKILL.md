---
name: inspect-pencil-node
description: "Pencil CLI（`pencil`コマンド）だけを使って、.penファイル（Pencilで作成されたデザインファイル）の中のNodeのデザインデータ（属性・構造）とスクリーンショット画像を読み取り専用で取得するスキル。Node IDが分かっているケースだけでなく、名前の正規表現（例: 「ヘッダー」「.*Button」）、Nodeタイプ（frame / text / image など）、再利用可能コンポーネント、特定フレーム配下、ドキュメント全体のトップレベルなど、**ID以外の指定方法**にも対応する。ユーザーが「.penのこのNodeの中身を見せて」「特定コンポーネントのデザインデータを取り出して」「Nodeのスクリーンショットだけ欲しい」「ヘッダーの構造を確認したい」「ボタンのスタイルをコピーしたい」「再利用可能コンポーネント一覧を見せて」「ドキュメント全体の構造を覗きたい」「全てのテキストNodeを取得して」のように.pen内の要素の調査・参照・確認・抜き出しを依頼した場合に必ずこのスキルを使う。インタラクティブモード（`pencil interactive`）で `batch_get` の `nodeIds` / `patterns` / `parentId` を使い分けてNode属性をJSONで取得し、`get_screenshot` / `export_nodes` で画像を`.pen`と同階層の`snapshots/`にPNG出力する。編集はしない（`save()`を呼ばない）ため、対象ファイルは絶対に書き換わらない。Pencil MCPには依存せず`pencil`コマンドのみで完結。"
---

# Inspect Pencil Node

Pencil CLI（`pencil`コマンド）**のみ**で `.pen` デザインファイル内のNodeのデータと画像を**読み取り専用**で取得するスキル。MCPサーバーには依存しません。公式ドキュメント: [docs.pencil.dev/for-developers/pencil-cli](https://docs.pencil.dev/for-developers/pencil-cli)

姉妹スキル `edit-pencil-design` が「編集 + 編集Nodeのスクショ」を担当するのに対し、こちらは「Nodeを覗き見るだけ」を担当し、`.pen` の中身は一切書き換えません。

Nodeの指定方法は5系統に対応し、併用も可能です。`parentId` で検索範囲を特定Nodeのサブツリーに絞れます。

1. **Node ID指定** — `nodeIds: ["..."]`
2. **名前パターン検索（Regex）** — `patterns: [{ name: "Header.*" }]`
3. **タイプ指定** — `patterns: [{ type: "frame" }]`（`frame` / `group` / `rectangle` / `ellipse` / `line` / `polygon` / `path` / `text` / `connection` / `note` / `icon_font` / `image` / `ref`）
4. **再利用可能コンポーネント抽出** — `patterns: [{ reusable: true }]`
5. **トップレベル取得** — `nodeIds` も `patterns` も渡さない（ドキュメント直下の子Nodeが返る）

# 設計思想

Pencil CLI のうち、このスキルで使うのは**インタラクティブモード**（`pencil interactive -i -o`）のみ。`batch_get` / `get_screenshot` / `get_editor_state` / `exit` を heredoc で呼びます。エージェントモード（`pencil --in --out --prompt`）はAI編集用なので使いません。

`.pen` は暗号化バイナリで `Read` / `Grep` では読めないため、Node属性の取得・スクリーンショット出力はすべてインタラクティブモード経由で行います。

# 前提条件の確認

1. `pencil version` — 未インストールなら `npm install -g @pencil.dev/cli` を案内（Node.js 18以上必要）
2. `pencil status` — 未認証なら `pencil login`、または `PENCIL_CLI_KEY` 環境変数の設定を案内
3. 対象の `.pen` ファイルが存在するか
4. ユーザーの取得対象指定を上記5系統（＋`parentId` 限定）のどれかにマップする。どれも曖昧な場合だけ `get_editor_state()` でツリーを取って候補を提示

# 実行ルール

## ルール1: 読み取り目的では `save()` を絶対に呼ばない

ヘッドレス実行では `-o` の指定が必須なので、入力と同じパスを `-o` に渡します。**`save()` を呼ばない限りディスクへの書き込みは発生しません** — これがファイル不変性の担保です。heredocの末尾は必ず `exit()` で締めます。

```bash
pencil interactive -i path/to/design.pen -o path/to/design.pen <<'EOF'
batch_get({ nodeIds: ["<node-id>"] })
exit()
EOF
```

## ルール2: インタラクティブモードを heredoc で非対話的に呼び出す

スクリプトから安定して呼ぶため、heredoc で固定のコマンド列を流し、結果を `${WORK_DIR}` 配下に保存します。

```bash
pencil interactive -i path/to/design.pen -o path/to/design.pen <<'EOF' > "${WORK_DIR}/out.json"
batch_get({ nodeIds: ["<node-id>"] })
exit()
EOF
```

**未確定な仕様**: 各シェル内ツールの完全な引数仕様（出力先パラメータ名、scale、padding 等）は公式ドキュメント未記載。`pencil interactive --help` でローカル実装を確認し、引数名が違えば調整してください。

### heredoc / シェルの改行展開を正しく扱う（重要）

長いJSON引数（特に `patterns: [{ name: "..." }]` の Regex/動的注入）を heredoc で流すとき、シェルが `\n` を実改行に展開するとJSONが壊れ、Pencilがパースエラーをサイレントに無視して「**結果が空**」「**想定と違うNodeセットが返る**」という失敗が起きます。読み取り専用なのでファイルは壊れませんが、調査結果が壊れて後続の判断を狂わせます。姉妹スキル `edit-pencil-design` と同じ改行ルールを必ず守ります。

| シェル / コマンド | `"a\nb"` の扱い |
|---|---|
| zsh の組み込み `echo` | **`\n` を実改行に展開**（デフォルト挙動） |
| bash の組み込み `echo` | デフォルトでは展開しない（`-e` で展開） |
| `printf '%s' "..."` | 移植性ありで `\n` を2文字のまま出力 |
| `print -r -- "..."` (zsh) | エスケープ解釈なし |
| heredoc `<<'EOF'`（クォート付） | **本文をリテラルのまま渡す**（`\n` は2文字のまま、変数展開も無し） |
| heredoc `<<EOF`（クォート無） | 変数展開・コマンド置換は行うが、リテラル `\n` は2文字のまま |

原則は「**JSON文字列リテラル内の `\n` は2文字（バックスラッシュ + n）のままPencilに届けること**」。

#### 改行を確実に2文字のまま渡すための4原則

1. **heredoc は最優先で `<<'EOF'`（シングルクォート付き）を使う** — Regex文字列内のバックスラッシュもそのままPencilに届く。

   ```bash
   pencil interactive -i path/to/design.pen -o path/to/design.pen <<'EOF' > "${WORK_DIR}/nodes.json"
   batch_get({ patterns: [{ name: "(?i)header|hero" }], readDepth: 2, searchDepth: 4 })
   exit()
   EOF
   ```

2. **動的な値は `jq` でJSONエンコードしてから `<<EOF`（クォート無し）に差し込む**。`echo "{\"name\": \"$pattern\"}"` のような自前組み立ては禁止（改行・ダブルクォート・バックスラッシュが含まれた瞬間に壊れる）。

   ```bash
   PATTERN_JSON=$(jq -Rs . <<< "(?i)header|hero|nav")
   # → 正しくエスケープされたJSON文字列リテラル（前後にダブルクォート付き）になる

   pencil interactive -i path/to/design.pen -o path/to/design.pen <<EOF > "${WORK_DIR}/nodes.json"
   batch_get({ patterns: [{ name: ${PATTERN_JSON} }], readDepth: 2 })
   exit()
   EOF
   ```

3. **`echo` を使わない。`printf '%s'` または `print -r --`（zsh）を使う**。

   ```bash
   # NG (zshで\nが実改行に化けてJSONが壊れる)
   ARGS=$(echo '{ "name": "line1\nline2" }')
   # OK
   ARGS=$(printf '%s' '{ "name": "line1\nline2" }')
   ```

4. **JSON値として改行が必要なら、リテラル `\n` の2文字で書く**（heredoc本文に実改行を含むテキストを直接書かない）。

#### 失敗を早く検出するセルフチェック

Pencilに流す前に「シェルが解釈した最終文字列」を `cat` で目視します。

```bash
cat > "${WORK_DIR}/cmds.txt" <<'EOF'
batch_get({ patterns: [{ name: "(?i)header" }] })
exit()
EOF
cat "${WORK_DIR}/cmds.txt"   # \n やバックスラッシュが2文字のまま残っていることを目視
pencil interactive -i path/to/design.pen -o path/to/design.pen < "${WORK_DIR}/cmds.txt" > "${WORK_DIR}/nodes.json"
```

`\n` が実改行に化けていたら即失敗。`<<'EOF'` に修正してやり直します。

## ルール3: 同時実行で競合しない一時ディレクトリを毎回確保する

中間ファイルの保存先を固定パスにすると、同じ `.pen` の同時 inspect で上書き衝突が起きます。開始時に `mktemp -d` で実行ごとに一意なディレクトリを確保します（ディレクトリ名の一意性がカーネル側で保証され、`trap` で途中失敗時も自動後始末される）。

```bash
WORK_DIR="$(mktemp -d -t pencil-inspect-XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT
```

中間JSONは必ず `${WORK_DIR}` 配下に置き、`/tmp/out.json` のような固定パスは使いません。

## ルール4: `batch_get` で対象Nodeを決定・取得する（ID指定にこだわらない）

`batch_get` は「IDで取る」「パターンで検索する」「親配下を取る」「トップレベルを取る」を1ツールでこなせるので、依頼の解像度に合わせて引数を組み立てます。

| ユーザーの依頼 | 使う引数 |
|---|---|
| 「id=`btn-cta` の中身を見せて」 | `nodeIds: ["btn-cta"]` |
| 「ヘッダー Nodeのプロパティを教えて」 | `patterns: [{ name: "(?i)header" }]` |
| 「全テキストNodeを抜き出して」 | `patterns: [{ type: "text" }]` |
| 「再利用可能コンポーネント一覧」 | `patterns: [{ reusable: true }]` |
| 「ヘッダー配下のNodeを全部」 | `nodeIds: ["<headerId>"], readDepth: 3`、または `parentId: "<headerId>", patterns: [{}]` |
| 「ざっと全体構造を見たい」 | 引数なし（ドキュメント直下が返る） |

`batch_get` の主な引数（MCP仕様。CLIも同等の引数名を受け付ける想定、差異があれば `pencil interactive --help` で確認）:

| 引数 | 意味 |
|---|---|
| `nodeIds` | 取得したい既知のNode ID配列 |
| `patterns` | 検索パターン配列。`name`(Regex) / `type` / `reusable` を任意に組み合わせる |
| `parentId` | 検索/取得をこのNodeのサブツリーに限定 |
| `searchDepth` | パターン検索が降りる深さ（省略時は無制限） |
| `readDepth` | 返却ツリーの深さ（省略時は対象Node＋直下の子のみ。`> 3` は重いので注意） |
| `resolveVariables` | `true` で variable 参照を実値に展開 |
| `resolveInstances` | `true` で `ref` コンポーネントインスタンスを実体展開 |
| `includePathGeometry` | `true` で `path` Nodeの幾何データを省略せず返す |

それでも候補が絞れない（「あのヘッダー的なやつ」のように曖昧）場合だけ、`get_editor_state()` でツリーを取ってから3〜5件の候補をユーザーに提示します。**ID必須ではない**のがポイントです。

```bash
pencil interactive -i path/to/design.pen -o path/to/design.pen <<'EOF' > "${WORK_DIR}/tree.json"
get_editor_state({ include_schema: true })
exit()
EOF
```

呼び出しの形はすべて同じで、`batch_get({ ... })` の引数だけ上表に従って差し替えます。既知のIDやbash変数を埋め込む場合は `<<EOF`（クォート無し）+ `jq` エンコード、固定リテラルなら `<<'EOF'` を使います（ルール2）。

得られたJSONは、報告で重要な属性（type / name / geometry / style / content / 子Nodeの id と name など）を要約して提示します。フルダンプが必要なら `${WORK_DIR}/nodes.json` の絶対パスも併記します。

**注意**: `patterns` 検索や大きい `readDepth` は返却JSONがコンテキストを溢れさせることがあります。最初は `readDepth: 1〜2`、`searchDepth: 3〜4` で軽く取り、必要に応じて深掘りします。

## ルール5: `get_screenshot` / `export_nodes` で画像を取得し `snapshots/` に保存する

画像は `.pen` と同階層の `snapshots/` に保存し、ファイル名にタイムスタンプを必ず含めます（同時実行・繰り返し実行での衝突回避）。

- 単一Node → `get_screenshot`。**`nodeId: "document"` でドキュメント全体**もレンダリング可能
- 複数Node → `export_nodes` が効率的。`batch_get` の `patterns` で見つかったIDをそのまま渡す

```bash
mkdir -p "$(dirname path/to/design.pen)/snapshots"
TS="$(date +%Y%m%d-%H%M%S)"

# 単一Node
pencil interactive -i path/to/design.pen -o path/to/design.pen <<EOF
get_screenshot({ nodeId: "${NODE_ID}", out: "path/to/snapshots/<file>-<node>-${TS}.png", scale: 2 })
exit()
EOF

# 複数Node
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

ファイル命名規則: `<.penファイル名のステム>-<Node名 or Node ID短縮>-<YYYYMMDD-HHMMSS>.png`（例: `login.pen` の `header` Node → `snapshots/login-header-20260627-160500.png`）。スケールは視認性のため `scale: 2` を推奨。

## ルール6: データとスクリーンショットを同一heredocでまとめて取得してもよい

`batch_get` と `get_screenshot` は同じセッションで連続実行できます。標準出力に両者の結果が混ざるため、分離が容易な簡単なケースでは1回にまとめ、複雑なケースでは別々に呼びます。

```bash
pencil interactive -i path/to/design.pen -o path/to/design.pen <<EOF > "${WORK_DIR}/combined.txt"
batch_get({ nodeIds: ["${NODE_ID}"] })
get_screenshot({ nodeId: "${NODE_ID}", out: "path/to/snapshots/<file>-<node>-${TS}.png", scale: 2 })
exit()
EOF
```

## ルール7: 実行結果をユーザーに伝える

`.pen` の中身は直接確認できないため、最終報告に含めます:

- 何をクエリしたか（Node ID指定 / 名前パターン / type / reusable / parentId / トップレベル のいずれか）
- ヒットしたNode一覧（id / name / type を簡潔に。パターン検索の場合は件数も）
- Node属性の要約（geometry / 主要style / content / 子Nodeなど）
- 生データJSONの保存パス（`${WORK_DIR}` 配下 — trap によりセッション終了で消える旨も一言添える）
- 出力したスクリーンショット画像の絶対パス（`snapshots/` に永続化）

ユーザーがJSONを永続的に欲しがった場合は `cp "${WORK_DIR}/nodes.json" <希望パス>` を案内します。

# 標準ワークフロー

1. **前提確認**: `pencil version`、`pencil status`、対象 `.pen` の存在
2. **作業ディレクトリ確保**: `WORK_DIR="$(mktemp -d -t pencil-inspect-XXXXXX)"` と `trap 'rm -rf "$WORK_DIR"' EXIT`
3. **`snapshots/` 準備**: `mkdir -p <.penと同じディレクトリ>/snapshots`
4. **取得スコープの決定**: 依頼を「ID / 名前Regex / type / reusable / parentId / トップレベル」にマップ。曖昧なときだけ `get_editor_state()` で候補を提示
5. **属性取得**: heredoc で `batch_get({ ... })` → `${WORK_DIR}/nodes.json`（必要なら `readDepth` / `searchDepth` / `resolveVariables` を調整）
6. **画像取得**: 単一Nodeは `get_screenshot`、複数は `export_nodes`、全体は `get_screenshot({ nodeId: "document" })` → `snapshots/<file>-<scope>-<timestamp>.png`
7. **要約報告**: ヒットNode一覧・属性の要点・画像パスを提示

# 使用例

## 例1: ログイン画面のヘッダーNodeを覗き見る（ID未知 → ツリーから特定）

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

返却JSONから type=Frame, name="Header" のNode（仮に id="header-01"）を特定したあと:

```bash
TS="$(date +%Y%m%d-%H%M%S)"

# 属性 + 画像を1回のセッションで
pencil interactive -i designs/login.pen -o designs/login.pen <<EOF > "${WORK_DIR}/combined.txt"
batch_get({ nodeIds: ["header-01"] })
get_screenshot({ nodeId: "header-01", out: "designs/snapshots/login-header-${TS}.png", scale: 2 })
exit()
EOF
```

報告例: Node `header-01`（type=Frame, name="Header"）、主要属性（幅 1280px / 高さ 64px / 背景色 #FFFFFF / 子要素: Logo, NavMenu, ProfileButton）、スクリーンショットパス、生データJSONパス（セッション終了で削除される旨を添える）。

## 例2: 再利用可能コンポーネントを一覧化し画像も一括出力（ID未指定）

ユーザー: 「`system.pen` にどんな再利用可能コンポーネントが入ってる？ 全部教えて」

```bash
mkdir -p design-system/snapshots

WORK_DIR="$(mktemp -d -t pencil-inspect-XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

TS="$(date +%Y%m%d-%H%M%S)"

# 再利用可能コンポーネントを一括検索
pencil interactive -i design-system/system.pen -o design-system/system.pen <<'EOF' > "${WORK_DIR}/components.json"
batch_get({ patterns: [{ reusable: true }], readDepth: 2, searchDepth: 4 })
exit()
EOF

# 検出されたIDをjqで取り出して画像も一括出力
COMP_IDS=$(jq -r '[.. | objects | select(.reusable==true) | .id] | unique | @json' "${WORK_DIR}/components.json")

pencil interactive -i design-system/system.pen -o design-system/system.pen <<EOF
export_nodes({
  nodes: $(echo "$COMP_IDS" | jq -r '. | map({id: ., out: "design-system/snapshots/system-\(.)-'"${TS}"'.png", format: "png", scale: 2})')
})
exit()
EOF
```

報告では検出したコンポーネントの type / name / 主要プロパティを表形式で、画像パスと生データJSONパスを併記します。パターン検索でヒットが多い場合は一覧を提示し、ユーザーが選んだものに対して画像取得を続行します。

# 主要オプション/コマンド早見表

## インタラクティブモード起動オプション

| オプション | 用途 |
|---|---|
| `--in / -i <path>` | 入力 `.pen` ファイル |
| `--out / -o <path>` | 出力 `.pen` ファイル（ヘッドレス時必須。`save()`を呼ばないため書き換わらない） |
| `--help / -h` | ツールリファレンスを表示 |

## シェル内ツール

| ツール | 用途 |
|---|---|
| `get_editor_state({ include_schema: true })` | Nodeツリー・メタデータ・スキーマの取得（曖昧時のフォールバック） |
| `batch_get({ nodeIds, patterns, parentId, searchDepth, readDepth, resolveVariables, resolveInstances, includePathGeometry })` | **本スキルの中核**。ID指定 / Regex・タイプ・reusable検索 / 部分ツリー限定 / 引数なしでトップレベル取得 |
| `get_screenshot({ nodeId: "..." or "document", out: "...", scale: 2 })` | 単一NodeまたはドキュメントをPNGレンダリング |
| `export_nodes({ nodes: [{id, out, format, scale}, ...] })` | 複数NodeをまとめてPNG/JPEG/WEBP/PDFへ出力 |
| `snapshot_layout(...)` | レイアウトのスナップショット（必要に応じて） |
| `get_variables()` | 変数の取得 |
| `exit()` | シェル終了（heredoc末尾に必ず置く） |
| `save()` | ディスクへ書き出し（**このスキルでは絶対に呼ばない**） |

# トラブルシューティング

- **`pencil: command not found`**: `npm install -g @pencil.dev/cli` を案内（Node.js 18以上必要）
- **認証エラー**: `pencil login`、または `PENCIL_CLI_KEY` 環境変数を設定
- **`-o` が必須エラー**: ヘッドレス実行では `-o` 必須。入力と同じパスを指定し、`save()` を呼ばなければ変更されない
- **`batch_get` / `get_screenshot` の引数名エラー**: 出力先パラメータ名（`out` / `path` / `output` 等）や `scale` / `format` はドキュメント未記載。`pencil interactive --help` で確認して合わせる
- **Node ID が分からない**: `patterns`（name / type / reusable）や `parentId`、引数なし（トップレベル）でID不要の取得ができる。まずそれを試し、絞り切れないときだけ `get_editor_state()` で候補を提示
- **`patterns` 検索の返却が大きすぎる**: `readDepth` を 1〜2 に下げる、`searchDepth` を絞る、`parentId` で範囲を限定する
- **`.pen` ファイルが見つからない**: パスを再確認
- **大きいNodeで画像取得が遅い/タイムアウト**: `scale: 1` に下げて再試行。それでも遅ければ子Nodeに絞る
- **誤ってファイルを書き換えた気がする**: `save()` を呼ばない限り原則変わらない。心配なら git diff で確認（事前に `git status` で clean を確認しておくとよい）
- **`batch_get` の結果が空 / 想定と違うNodeセット**: heredoc/シェルの改行展開でJSON引数（特に Regex 文字列）が壊れた可能性が高い。ルール2を再確認:
  1. `<<EOF` で開いていないか → `<<'EOF'` に切り替える
  2. `echo` で組み立てた値を埋め込んでいないか → `jq -Rs .` か `printf '%s'` に置き換える
  3. 実改行を含むテキストを直接書いていないか → リテラル `\n` の2文字で書く
  4. セルフチェックの `cat` で `\n` やバックスラッシュが2文字のまま残っていることを目視する
