---
name: inspect-pencil-node
description: Pencil CLI（`pencil`コマンド）だけを使って、.penファイル（Pencilで作成されたデザインファイル）の中のNodeのデザインデータ（属性・構造）とスクリーンショット画像を読み取り専用で取得するスキル。Node IDが分かっているケースだけでなく、名前の正規表現（例: 「ヘッダー」「.*Button」）、Nodeタイプ（frame / text / image など）、再利用可能コンポーネント、特定フレーム配下、ドキュメント全体のトップレベルなど、**ID以外の指定方法**にも対応する。ユーザーが「.penのこのNodeの中身を見せて」「特定コンポーネントのデザインデータを取り出して」「Nodeのスクリーンショットだけ欲しい」「ヘッダーの構造を確認したい」「ボタンのスタイルをコピーしたい」「再利用可能コンポーネント一覧を見せて」「ドキュメント全体の構造を覗きたい」「全てのテキストNodeを取得して」のように.pen内の要素の調査・参照・確認・抜き出しを依頼した場合に必ずこのスキルを使う。インタラクティブモード（`pencil interactive`）で `batch_get` の `nodeIds` / `patterns` / `parentId` を使い分けてNode属性をJSONで取得し、`get_screenshot` / `export_nodes` で画像を`.pen`と同階層の`snapshots/`にPNG出力する。編集はしない（`save()`を呼ばない）ため、対象ファイルは絶対に書き換わらない。Pencil MCPには依存せず`pencil`コマンドのみで完結。
---

# Inspect Pencil Node

このスキルは、Pencil CLI（`pencil`コマンド）**のみ**で `.pen` デザインファイル内のNodeのデータと画像を**読み取り専用**で取得するスキルです。MCPサーバーには依存しません。公式ドキュメント: [docs.pencil.dev/for-developers/pencil-cli](https://docs.pencil.dev/for-developers/pencil-cli)。

姉妹スキル `edit-pencil-design` が「編集 + 編集Nodeのスクショ」を担当するのに対し、こちらは「**Nodeを覗き見るだけ**」を担当します。`.pen` の中身は一切書き換えません。

Nodeの指定方法は次の5系統に対応します。

1. **Node ID指定** — `nodeIds: ["..."]`
2. **名前パターン検索（Regex）** — `patterns: [{ name: "Header.*" }]`
3. **タイプ指定** — `patterns: [{ type: "frame" }]`（`frame` / `group` / `rectangle` / `ellipse` / `line` / `polygon` / `path` / `text` / `connection` / `note` / `icon_font` / `image` / `ref`）
4. **再利用可能コンポーネント抽出** — `patterns: [{ reusable: true }]`
5. **トップレベル取得** — `nodeIds` も `patterns` も渡さない（ドキュメント直下の子Nodeが返る）

これらは併用可能で、`parentId` で検索範囲を特定Nodeのサブツリーに絞ることもできます。

# 設計思想

Pencil CLI には2つの実行モードがあります:

| モード | 起動方法 | このスキルでの用途 |
|---|---|---|
| エージェントモード | `pencil --in --out --prompt` | **使わない**（AI編集モードなので読み取り目的では不要） |
| **インタラクティブモード** | `pencil interactive -i -o` | このスキルの中核。`batch_get` / `get_screenshot` / `get_editor_state` / `exit` を heredoc で呼ぶ |

`.pen` は暗号化バイナリで `Read` / `Grep` では中身が見えないため、Node属性の取得・スクリーンショット出力はすべてインタラクティブモード経由で行います。

# 重要な前提

- **完全な読み取り専用**。インタラクティブシェルで `save()` を呼ばないことで、Nodeを覗いても `.pen` ファイル自体は1バイトも変更されません
- **取得対象はNode単位**。ID/名前パターン/タイプ/再利用可能フラグ/親Node配下のいずれかでスコープしてデータと画像を返します
- **Pencil MCPには依存しない**。`pencil` コマンドだけで完結

# 前提条件の確認

1. `pencil` コマンドが利用可能か（`pencil version` で確認）
   - 未インストールなら `npm install -g @pencil.dev/cli` をユーザーに案内（Node.js 18以上必要）
2. 認証済みか（`pencil status` で確認）
   - 未認証なら `pencil login`、または `PENCIL_CLI_KEY` 環境変数を設定するよう案内
3. 対象の `.pen` ファイルが存在するか
4. ユーザーが取得対象をどう指定しているか（次のいずれか）
   - **Node ID** — 既知の `id` を直接指定
   - **名前パターン** — 「ヘッダー」「Primary CTA」「`.*Button`」など Regex で書ける名前ヒント
   - **Nodeタイプ** — 「テキスト全部」「全フレーム」「画像Nodeのみ」など
   - **再利用可能コンポーネント** — デザインシステムの「コンポーネント一覧が欲しい」
   - **特定フレーム配下** — 「ヘッダーの中のNodeを全部」など、親Nodeのサブツリー限定
   - **ドキュメント全体（トップレベル）** — 「ざっと構造を見たい」など
   - どれも曖昧な場合は `get_editor_state()` でツリーを取って候補をユーザーに提示する

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

### heredoc / シェルの改行展開を正しく扱う（重要）

`pencil interactive` に長いJSON引数（特に `batch_get({ patterns: [{ name: "..." }], parentId: "..." })` の Regex/動的注入）を heredoc で流すとき、シェルが文字列内の `\n` をどう解釈するかを把握していないと、JSON引数が壊れて Pencil 側がパースエラーをサイレントに無視し、**「結果が空でなんとなく取れていないように見える」「想定と違うNodeセットが返る」** といった失敗が起きます。本スキルは読み取り専用（`save()` を呼ばない）なのでファイルは書き換わりませんが、調査結果が壊れる事故は同じく成立するため、姉妹スキル `edit-pencil-design` と同じ改行ルールを必ず守ります。

まずシェルごとの挙動を頭に入れます。

| シェル / コマンド | `"a\nb"` をどう扱うか |
|---|---|
| zsh の組み込み `echo` | **`\n` を実改行に展開**（デフォルト挙動） |
| bash の組み込み `echo` | デフォルトでは展開しない（`-e` で展開） |
| `printf '%s' "..."` | 移植性ありで `\n` をそのまま2文字として出力 |
| `print -r -- "..."` (zsh) | エスケープ解釈なし |
| heredoc `<<'EOF'`（クォート付） | **本文をリテラルとして渡す**（`\n` は2文字のまま、変数展開も無し） |
| heredoc `<<EOF`（クォート無） | 変数展開・コマンド置換は行うが、リテラル `\n` は2文字のまま |

ポイントは「**JSON文字列リテラル内の `\n` は2文字（バックスラッシュ + n）のままPencilに届かなければならない**」ということ。シェル側で改行に化けるとJSONが構文エラーになります。

#### 改行を確実に2文字のまま渡すための4原則

1. **heredoc は最優先で `<<'EOF'`（シングルクォート付き）を使う**。変数展開もコマンド置換もエスケープ解釈も全部止まるので、本文に書いたJSONがそのままPencilに届きます。

   ```bash
   pencil interactive -i path/to/design.pen -o path/to/design.pen <<'EOF' > "${WORK_DIR}/nodes.json"
   batch_get({ patterns: [{ name: "(?i)header|hero" }], readDepth: 2, searchDepth: 4 })
   exit()
   EOF
   ```

   `"(?i)header|hero"` のような Regex 文字列内のバックスラッシュも、`<<'EOF'` で囲んでいる限りそのままPencilに届きます。

2. **動的な値を埋め込む必要があるなら `jq` でJSONエンコード**してから heredoc に差し込みます。`echo "{\"name\": \"$pattern\"}"` のような自前組み立ては絶対に避けます（`$pattern` に改行・ダブルクォート・バックスラッシュが含まれた瞬間に壊れる）。

   ```bash
   # ユーザー入力（例えば Regex パターン）を安全にJSONリテラルに変換
   PATTERN_JSON=$(jq -Rs . <<< "(?i)header|hero|nav")
   # → "(?i)header|hero|nav" という、正しくエスケープされたJSON文字列リテラルになる

   IDS_JSON=$(jq -nc --argjson ids '["main-frame"]' '$ids')

   pencil interactive -i path/to/design.pen -o path/to/design.pen <<EOF > "${WORK_DIR}/nodes.json"
   batch_get({
     patterns: [{ name: ${PATTERN_JSON} }],
     parentId: ${IDS_JSON}[0],
     readDepth: 2
   })
   exit()
   EOF
   ```

   `<<EOF`（クォート無し）なら `${PATTERN_JSON}` が展開されますが、`jq -Rs .` が改行・特殊文字を **JSONエスケープ済みの文字列**（前後にダブルクォート付き）に変換してくれているので、heredoc内に貼り込んでも構文が壊れません。

3. **`echo` を使わない、`printf '%s\n'` または `print -r --` を使う**。heredocを使わずに引数文字列を組み立てたい場面では、`echo` は禁止です。

   ```bash
   # NG (zshで\nが実改行に化けてJSONが壊れる)
   ARGS=$(echo '{ "name": "line1\nline2" }')

   # OK
   ARGS=$(printf '%s' '{ "name": "line1\nline2" }')
   # OK (zsh)
   ARGS=$(print -r -- '{ "name": "line1\nline2" }')
   ```

4. **JSON値として改行が必要なら、エディタ上では `\n` の2文字で書く**。heredoc本文に「実際の改行を含むテキスト」を書きたい誘惑がありますが、JSON文字列リテラルは本来改行を含めず `\n` で表現するのが正しいJSONです。シェル経路で改行が化けないかを毎回意識する負担を消すためにも、リテラル `\n` で書く規約に統一します。

   ```bash
   pencil interactive -i path/to/design.pen -o path/to/design.pen <<'EOF'
   batch_get({ patterns: [{ name: "line1\nline2" }] })
   exit()
   EOF
   ```

#### 失敗パターンを早く検出するためのセルフチェック

heredoc を組み立てた直後、Pencilに流す前に「シェルが解釈した最終文字列」を `cat` で目視できると事故が減ります。

```bash
cat > "${WORK_DIR}/cmds.txt" <<'EOF'
batch_get({ patterns: [{ name: "(?i)header" }] })
exit()
EOF
cat "${WORK_DIR}/cmds.txt"   # JSON文字列リテラル内の \n やバックスラッシュが2文字のまま残っていることを目視
pencil interactive -i path/to/design.pen -o path/to/design.pen < "${WORK_DIR}/cmds.txt" > "${WORK_DIR}/nodes.json"
```

`cat` 出力内に JSON文字列リテラル内のはずだった `\n` が **実改行になっていたら即失敗**です。`<<'EOF'`（シングルクォート付き）に修正してやり直します。読み取り専用とはいえ、壊れたクエリは「結果が空」「想定外のNodeセット」を引き起こし、後続の判断を狂わせます。

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

## ルール4: 対象Nodeの決定（ID指定だけにこだわらない）

`batch_get` は **「IDで取る」「パターンで検索する」「親配下を取る」「トップレベルを取る」を1ツールで全部こなせる** ので、ユーザーの依頼の解像度に合わせて引数を組み立てます。

| ユーザーの依頼 | 使う引数 |
|---|---|
| 「id=`btn-cta` の中身を見せて」 | `nodeIds: ["btn-cta"]` |
| 「ヘッダー Nodeのプロパティを教えて」 | `patterns: [{ name: "(?i)header" }]` |
| 「全テキストNodeを抜き出して」 | `patterns: [{ type: "text" }]` |
| 「再利用可能コンポーネント一覧」 | `patterns: [{ reusable: true }]` |
| 「ヘッダー配下のNodeを全部」 | `nodeIds: ["<headerId>"], readDepth: 3`、または `parentId: "<headerId>", patterns: [{}]` |
| 「ざっと全体構造を見たい」 | 引数なし（ドキュメント直下が返る） |

`batch_get` の主な引数（MCP 仕様、CLI インタラクティブモードも同等の引数名で受け付ける想定。差異があれば `pencil interactive --help` で確認）:

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

それでも候補が絞れない（ユーザーが「あのヘッダー的なやつ」のように曖昧）な場合だけ、`get_editor_state()` でツリーを取ってからユーザーに3〜5件の候補を提示します。**ID必須ではない** のがポイントです。

```bash
pencil interactive -i path/to/design.pen -o path/to/design.pen <<'EOF' > "${WORK_DIR}/tree.json"
get_editor_state({ include_schema: true })
exit()
EOF
```

## ルール5: `batch_get` で属性を取得する具体例

**(a) Node ID で取る**

```bash
pencil interactive -i path/to/design.pen -o path/to/design.pen <<EOF > "${WORK_DIR}/nodes.json"
batch_get({ nodeIds: [${NODE_IDS_JSON_LIST}] })
exit()
EOF
```

`${NODE_IDS_JSON_LIST}` は `"id1", "id2"` のようなカンマ区切りJSON文字列。`<<EOF`（クォートなし）にすることでbash変数を展開できます。

**(b) 名前のRegexで取る**

```bash
pencil interactive -i path/to/design.pen -o path/to/design.pen <<'EOF' > "${WORK_DIR}/nodes.json"
batch_get({ patterns: [{ name: "(?i)header|nav" }], searchDepth: 4, readDepth: 2 })
exit()
EOF
```

**(c) タイプで一括取得（全テキスト/全フレームなど）**

```bash
pencil interactive -i path/to/design.pen -o path/to/design.pen <<'EOF' > "${WORK_DIR}/nodes.json"
batch_get({ patterns: [{ type: "text" }], readDepth: 1 })
exit()
EOF
```

**(d) 再利用可能コンポーネント一覧（デザインシステム調査の定番）**

```bash
pencil interactive -i path/to/design.pen -o path/to/design.pen <<'EOF' > "${WORK_DIR}/components.json"
batch_get({ patterns: [{ reusable: true }], readDepth: 2, searchDepth: 3 })
exit()
EOF
```

**(e) 特定フレーム配下に絞って検索**

```bash
pencil interactive -i path/to/design.pen -o path/to/design.pen <<EOF > "${WORK_DIR}/nodes.json"
batch_get({ parentId: "${HEADER_ID}", patterns: [{ type: "text" }] })
exit()
EOF
```

**(f) パターンも nodeIds も指定しない → ドキュメントのトップレベル**

```bash
pencil interactive -i path/to/design.pen -o path/to/design.pen <<'EOF' > "${WORK_DIR}/top.json"
batch_get({})
exit()
EOF
```

得られたJSONから、ユーザーへの報告で重要な属性（type / name / geometry / style / content / 子Nodeのid と name など）を要約します。生のJSON全体ではなく要点を整理して提示するのが親切です。フルダンプが必要なら `${WORK_DIR}/nodes.json` の絶対パスも併記します。

**注意**: `patterns` 検索や `readDepth` が大きい場合、返却JSONがコンテキストを溢れさせる量になることがあります。最初は `readDepth: 1〜2`、`searchDepth: 3〜4` で軽く取り、必要に応じて深掘りするのが安全です。

## ルール6: `get_screenshot` / `export_nodes` で画像を取得し `snapshots/` に保存する

画像は `.pen` ファイルと同じディレクトリ配下の `snapshots/` に保存します。同時実行や繰り返し inspect でファイル名が衝突しないよう、ファイル名にタイムスタンプを必ず含めます。

スクリーンショット側もNodeをIDで指定するのが基本ですが、特殊な指定として **`nodeId: "document"` でドキュメント全体** をレンダリングできます（全体ビューが欲しいときに便利）。`batch_get` の `patterns` で見つかった複数Nodeを画像化したい場合は、得られたIDを `export_nodes` の `nodeIds` にそのまま渡すのが効率的です。

```bash
mkdir -p "$(dirname path/to/design.pen)/snapshots"
TS="$(date +%Y%m%d-%H%M%S)"

# 単一Node
pencil interactive -i path/to/design.pen -o path/to/design.pen <<EOF
get_screenshot({ nodeId: "${NODE_ID}", out: "path/to/snapshots/<file>-<node>-${TS}.png", scale: 2 })
exit()
EOF

# ドキュメント全体
pencil interactive -i path/to/design.pen -o path/to/design.pen <<EOF
get_screenshot({ nodeId: "document", out: "path/to/snapshots/<file>-document-${TS}.png", scale: 1 })
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

- 何をクエリしたか（Node ID指定 / 名前パターン / type / reusable / parentId / トップレベル のいずれか）
- ヒットしたNode一覧（id / name / type を簡潔に。パターン検索の場合は件数も）
- Node属性の要約（geometry / 主要style / content / 子Nodeなど）
- 生データJSONの保存パス（`${WORK_DIR}` 配下 — セッション中のみ有効、後始末で消える）
- 出力したスクリーンショット画像の絶対パス（`.pen` と同階層の `snapshots/` に永続化）

ユーザーがJSONを永続的に手元に欲しがった場合は、`cp "${WORK_DIR}/nodes.json" <ユーザー希望パス>` で別途コピーすることを案内します。

# 標準ワークフロー

ユーザーから「`xxx.pen` の〇〇のデータと画像を取得して」のような依頼を受けたときの標準フロー。

1. **前提確認**: `pencil version`、`pencil status`、対象 `.pen` ファイルの存在
2. **作業ディレクトリ確保**: `WORK_DIR="$(mktemp -d -t pencil-inspect-XXXXXX)"` と `trap 'rm -rf "$WORK_DIR"' EXIT`
3. **`snapshots/` ディレクトリ準備**: `mkdir -p <.penと同じディレクトリ>/snapshots`
4. **取得スコープの決定**: 依頼内容から「ID / 名前Regex / type / reusable / parentId / トップレベル」のいずれかにマップ。曖昧なときだけ `get_editor_state()` で候補を提示
5. **属性取得**: heredoc で `batch_get({ ... })` を呼び `${WORK_DIR}/nodes.json` に保存（必要なら `readDepth` / `searchDepth` / `resolveVariables` を調整）
6. **画像取得**: 単一Nodeなら `get_screenshot`、複数なら `export_nodes`、ドキュメント全体なら `get_screenshot({ nodeId: "document" })` を heredoc で実行し `snapshots/<file>-<scope>-<timestamp>.png` に保存
7. **要約報告**: ヒットしたNode一覧と属性の要点、画像パスをユーザーに提示。フルダンプが必要なら `${WORK_DIR}/nodes.json` のパスも併記（`trap` でセッション終了時に消えることも一言添える）

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

## 例4: デザインシステムの再利用可能コンポーネントを一覧化（ID未指定）

ユーザー: 「`system.pen` にどんな再利用可能コンポーネントが入ってる？ 全部教えて」

Node IDは一切分からないケース。`patterns: [{ reusable: true }]` で一発検索します。

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

ユーザーへの報告:
- 検出: 12個の再利用可能コンポーネント（Button-Primary, Button-Secondary, Input-Text, Card-Default, ...）
- 各コンポーネントの type / name / 主要プロパティを表形式で
- 画像: `design-system/snapshots/system-*-20260627-160500.png`（12枚）
- 生データJSON: `${WORK_DIR}/components.json`

## 例5: 名前パターン検索 — 「ヘッダー」っぽいNodeを全部探す

ユーザー: 「`marketing/landing.pen` の中で『ヘッダー』っぽいNode全部教えて」

```bash
WORK_DIR="$(mktemp -d -t pencil-inspect-XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

pencil interactive -i marketing/landing.pen -o marketing/landing.pen <<'EOF' > "${WORK_DIR}/headers.json"
batch_get({
  patterns: [{ name: "(?i)header|hero|topbar|nav" }],
  readDepth: 2,
  searchDepth: 5
})
exit()
EOF
```

ヒットした各Nodeについて id / name / type / 親Node を表で報告し、ユーザーが「これ」と選んだものに対して画像取得を続行します。

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
| `get_editor_state({ include_schema: true })` | Nodeツリー・メタデータ・スキーマの取得（候補探索や曖昧時のフォールバック） |
| `batch_get({ nodeIds, patterns, parentId, searchDepth, readDepth, resolveVariables, resolveInstances, includePathGeometry })` | **本スキルの中核**。`nodeIds` でID指定、`patterns: [{ name, type, reusable }]` でRegex/タイプ/再利用可能フラグ検索、`parentId` で部分ツリー限定、引数なしでドキュメントのトップレベル子を取得 |
| `get_screenshot({ nodeId: "..." or "document", out: "...", scale: 2 })` | **単一NodeまたはドキュメントをPNGレンダリング**（本スキルの中核） |
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
- **Node ID が分からない**: そもそも本スキルは `patterns: [{ name }]` / `patterns: [{ type }]` / `patterns: [{ reusable: true }]` / `parentId` / 引数なし（トップレベル）でID不要の取得ができる。まずそれを試し、それでも対象が絞り切れないときだけ `get_editor_state()` でツリーを取って候補を提示
- **`patterns` 検索の返却が大きすぎる**: `readDepth` を 1〜2 に下げる、`searchDepth` を絞る、`parentId` で範囲を限定する
- **`.pen` ファイルが見つからない**: パスを再確認
- **大きいNodeで画像取得が遅い/タイムアウト**: `scale` を 1 に下げて再試行。それでも遅ければ親ではなく子Nodeに絞って取得
- **誤ってファイルを書き換えてしまった気がする**: このスキルは `save()` を呼ばないので原則変わらない。心配な場合は git で diff 確認、もしくは事前に `git status` で対象ファイルが clean であることを確認しておく
- **`batch_get` の結果が空 / 想定と違うNodeセットになる**: heredoc/シェルの改行展開でJSON引数（特に `patterns: [{ name: "..." }]` の Regex 文字列）が壊れた可能性が高い。ルール2の「heredoc / シェルの改行展開を正しく扱う」を再確認:
  1. heredocを `<<EOF` で開いていないか → `<<'EOF'`（シングルクォート）に切り替える
  2. JSON文字列内に `echo` で組み立てた値を埋め込んでいないか → `jq -Rs .` か `printf '%s' ...` に置き換える
  3. heredoc内に「実改行を含むテキスト」を直接書いていないか → JSON文字列リテラルとして `\n` の2文字で書く
  4. ルール2のセルフチェック手順で `cat "${WORK_DIR}/cmds.txt"` を流し、`\n` やバックスラッシュが2文字のまま残っていることを目視確認する
