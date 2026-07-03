---
name: edit-pencil-design
description: Pencil CLI（`pencil`コマンド）だけを使って既存の.penファイル（Pencilで作成されたデザインファイル）をAIプロンプトで修正・更新するスキル。ユーザーが.penファイルの編集、ボタン追加、レイアウト変更、UIデザインの調整、Pencilデザインの更新などを依頼した場合に必ずこのスキルを使用する。エージェントモード（`pencil --in --out --prompt`）で同一パスを指定して既存ファイルを上書き編集し、編集後はインタラクティブモード（`pencil interactive`）でNodeツリーから「**編集したコンポーネントのNodeだけ**」を特定して`get_screenshot` / `export_nodes` でPNG出力し、`.pen`と同階層の`snapshots/`ディレクトリに保存する。Pencil MCPには依存せず、`pencil` コマンドのみで完結する。
---

# Edit Pencil Design

Pencil CLI（`pencil`コマンド）**のみ**で `.pen` デザインファイルをAI編集し、編集Nodeだけのスクリーンショットを残すスキル。MCPサーバーには依存しません。公式ドキュメント: [docs.pencil.dev/for-developers/pencil-cli](https://docs.pencil.dev/for-developers/pencil-cli)

# 設計思想

Pencil CLI の2つの実行モードを使い分けます:

| モード | 起動方法 | できること |
|---|---|---|
| **エージェントモード** | `pencil --in --out --prompt` | AIプロンプトで `.pen` を編集（プロンプト編集はこのモード**のみ**） |
| **インタラクティブモード** | `pencil interactive -i -o` | `get_editor_state()` / `get_screenshot()` / `export_nodes()` / `save()` / `exit()` などのツール呼び出し（AIプロンプト編集は不可） |

`.pen` は暗号化バイナリで `Read` / `Grep` では読めないため、Node構造の確認・Node ID取得・Node単位スクリーンショットはすべて `pencil interactive` 経由で行います。

# 重要な前提

- **既存ファイルをその場で上書き更新する**（別名出力は二重管理を生むため避ける）
- **スクリーンショットはファイル全体ではなく編集対象のNodeだけ**（差分レビューが容易になる）

# 前提条件の確認

1. `pencil version` — 未インストールなら `npm install -g @pencil.dev/cli` を案内（Node.js 18以上必要）
2. `pencil status` — 未認証なら `pencil login`、または `PENCIL_CLI_KEY` 環境変数の設定を案内
3. 対象の `.pen` ファイルが存在するか（編集対象なので先に存在している必要がある）

# 実行ルール

## ルール1: 編集モードの選択（エージェント / `interactive` どちらも可）

- **エージェントモード** `pencil --in path/to/design.pen --out path/to/design.pen --prompt "<修正内容>"`（短縮形 `-i` / `-o` / `-p`）— 自然言語で任せたい編集。大きめのリファイン、レイアウト調整、複数Nodeにまたがる修正向き
- **インタラクティブモードの `batch_design({...})`** — 「特定NodeのプロパティをこのJSONに置換」のような決定論的な編集向き。結果が予測可能で差分も追いやすい。ただし heredoc/シェルの改行展開を誤るとサイレントに失敗するため、**ルール2の安全規則を必ず守る**

どちらのモードでも既存ファイルの更新なので、`--in` と `--out` には**同じ `.pen` パス**を指定します。新規作成を依頼された場合のみ例外で、`--in` を省略して `--out` に新しいパスを指定します。

## ルール2: インタラクティブモードを heredoc で非対話的に呼び出す

`pencil interactive` は標準入力からコマンドを流せば非対話的に実行できます。

```bash
pencil interactive -i path/to/design.pen -o path/to/design.pen <<'EOF'
get_editor_state()
exit()
EOF
```

- `-i` と `-o` には**編集対象と同じ `.pen` パス**を指定（ヘッドレスモードでは `-o` が必須）
- `save()` を呼ばなければファイルへの変更は永続化されない（読み取りのみなら `save()` 不要）
- 最後に必ず `exit()` を呼ぶ

**未確定な仕様**: 各ツールの完全な引数仕様（出力先パラメータ名など）は公式ドキュメント未記載。`pencil interactive --help` / `pencil --help` でローカル実装を確認し、引数名が想定と異なれば調整してください。

### heredoc / シェルの改行展開を正しく扱う（重要）

長いJSON引数（特に `batch_design({...})`）を heredoc で流すとき、シェルが文字列内の `\n` を実改行に展開するとJSONが壊れ、Pencil側がパースエラーをサイレントに無視して `save()` だけが走り、小数点正規化（`13.995000000000001` → `13.995`）のような無害な差分だけがディスクに残ります。**過去に実害ありの事故パターンなので必読**。

| シェル / コマンド | `"a\nb"` の扱い |
|---|---|
| zsh の組み込み `echo` | **`\n` を実改行に展開**（デフォルト挙動） |
| bash の組み込み `echo` | デフォルトでは展開しない（`-e` で展開） |
| `printf '%s' "..."` | 移植性ありで `\n` を2文字のまま出力 |
| `print -r -- "..."` (zsh) | エスケープ解釈なし |
| heredoc `<<'EOF'`（クォート付） | **本文をリテラルのまま渡す**（`\n` は2文字のまま、変数展開も無し） |
| heredoc `<<EOF`（クォート無） | 変数展開・コマンド置換は行うが、リテラル `\n` は2文字のまま |

原則は「**JSON文字列リテラル内の `\n` は2文字（バックスラッシュ + n）のままPencilに届けること**」。シェル側で改行に化けるとJSONが構文エラーになります。

#### 改行を確実に2文字のまま渡すための4原則

1. **heredoc は最優先で `<<'EOF'`（シングルクォート付き）を使う** — 変数展開もエスケープ解釈も止まり、本文のJSONがそのままPencilに届く。

2. **動的な値は `jq` でJSONエンコードしてから heredoc に差し込む**。`echo "{\"text\": \"$user_input\"}"` のような自前組み立ては禁止（改行・ダブルクォート・バックスラッシュが含まれた瞬間に壊れる）。

   ```bash
   TEXT_JSON=$(jq -Rs . <<< "Hello
   World")
   # → "Hello\nWorld" という、正しくエスケープされたJSON文字列リテラルになる

   pencil interactive -i path/to/design.pen -o path/to/design.pen <<EOF
   batch_design({
     ops: [
       { type: "update", id: "title-01", props: { text: ${TEXT_JSON} } }
     ]
   })
   save()
   exit()
   EOF
   ```

   `<<EOF`（クォート無し）で変数展開しても、`jq -Rs .` がJSONエスケープ済み文字列（前後にダブルクォート付き）に変換しているため構文が壊れません。

3. **`echo` を使わない。`printf '%s'` または `print -r --`（zsh）を使う**。

   ```bash
   # NG (zshで\nが実改行に化けてJSONが壊れる)
   ARGS=$(echo '{ "text": "Hello\nWorld" }')
   # OK
   ARGS=$(printf '%s' '{ "text": "Hello\nWorld" }')
   ```

4. **JSON値として改行が必要なら、リテラル `\n` の2文字で書く**（heredoc本文に実改行を含むテキストを直接書かない）。

#### 失敗を早く検出するセルフチェック

Pencilに流す前に「シェルが解釈した最終文字列」を `cat` で目視します。

```bash
cat > "${WORK_DIR}/cmds.txt" <<'EOF'
batch_design({ ops: [{ type: "update", id: "t1", props: { text: "line1\nline2" } }] })
save()
exit()
EOF
cat "${WORK_DIR}/cmds.txt"   # JSON文字列リテラル内の \n が2文字のまま残っていることを目視
pencil interactive -i path/to/design.pen -o path/to/design.pen < "${WORK_DIR}/cmds.txt"
```

`\n` が実改行に化けていたら即失敗。`<<'EOF'` に修正してやり直します。

## ルール3: 同時実行で競合しない一時ディレクトリを毎回確保する

中間ファイルの保存先を固定パスにすると、同じ `.pen` の同時編集で上書き衝突が起きます。開始時に `mktemp -d` で実行ごとに一意なディレクトリを確保します（ディレクトリ名の一意性がカーネル側で保証され、`trap` で途中失敗時も自動後始末される）。

```bash
WORK_DIR="$(mktemp -d -t pencil-edit-XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT
```

`before.json` / `after.json` などの中間ファイルは**必ず `${WORK_DIR}` 配下**に置きます（`/tmp/before.json` のような固定パスは使わない）。

## ルール4: 編集の前後でNodeツリーを取得し、編集されたNodeを特定する

1. **編集前のスナップショット取得**
   ```bash
   pencil interactive -i path/to/design.pen -o path/to/design.pen <<'EOF' > "${WORK_DIR}/before.json"
   get_editor_state()
   exit()
   EOF
   ```

2. **編集（エージェントモード）** — 標準出力・標準エラーも `${WORK_DIR}` に流し、同時実行時のログ取り違えを防ぐ
   ```bash
   pencil --in path/to/design.pen --out path/to/design.pen --prompt "<具体的な指示>" \
     > "${WORK_DIR}/edit.log" 2>&1
   ```

3. **編集後のスナップショット取得** — 同様に `${WORK_DIR}/after.json` へ保存

4. **編集Nodeの特定**
   - `after` にあって `before` に無い `id` → 新規追加Node
   - 双方にあるが属性差分のある `id` → 変更Node
   - 判定が難しい場合（idの再採番、大規模な再構成など）は推定できる範囲で抽出し、残りはユーザーに確認。フォールバックとして影響を受けた最上位フレーム/コンポーネントのNode IDを1つ選んでスクリーンショットを取る

5. **「実質的な編集が無い」ケースの検出 → 編集失敗扱いにする**

   差分が「Node IDの追加・削除なし、type / name / children の構造変化なし、数値フォーマットの正規化のみ（例: `13.995000000000001` → `13.995`、`100.0` → `100`）」なら、JSONパースエラーで構造変更が適用されず `save()` だけ走った可能性が極めて高い（ルール2のトラブルの典型的な観測像）。編集失敗として報告し、再実行します。チェックは `jq` で数値表現を正規化してから diff:

   ```bash
   jq -S 'walk(if type == "number" then tonumber|tostring|tonumber else . end)' \
     "${WORK_DIR}/before.json" > "${WORK_DIR}/before.norm.json"
   jq -S 'walk(if type == "number" then tonumber|tostring|tonumber else . end)' \
     "${WORK_DIR}/after.json"  > "${WORK_DIR}/after.norm.json"

   if diff -q "${WORK_DIR}/before.norm.json" "${WORK_DIR}/after.norm.json" >/dev/null; then
     echo "編集失敗の疑い: 構造に有意な差分なし。heredocのJSON引数が壊れていないかルール2を再確認してください" >&2
     exit 1
   fi
   ```

   この検証は編集Node特定の直前に必ず通します。失敗が出たらルール2に戻って heredoc / echo の改行展開を確認します。

## ルール5: 編集したNodeだけをスクリーンショットし `snapshots/` に保存する

`.pen` と同階層の `snapshots/` にNode単位でPNG出力します。単一Nodeは `get_screenshot`、複数Nodeは `export_nodes`。引数名がエラーになったら `pencil interactive --help` で正しい名前に置き換えます。

```bash
mkdir -p "$(dirname path/to/design.pen)/snapshots"

# 複数Node
pencil interactive -i path/to/design.pen -o path/to/design.pen <<'EOF'
export_nodes({
  nodes: [
    { id: "<編集Node1 ID>", out: "path/to/snapshots/design-<node1-name>-<timestamp>.png", format: "png", scale: 2 },
    { id: "<編集Node2 ID>", out: "path/to/snapshots/design-<node2-name>-<timestamp>.png", format: "png", scale: 2 }
  ]
})
exit()
EOF

# 単一Node
pencil interactive -i path/to/design.pen -o path/to/design.pen <<'EOF'
get_screenshot({ nodeId: "<編集Node ID>", out: "path/to/snapshots/design-<node>-<timestamp>.png", scale: 2 })
exit()
EOF
```

- ファイル命名規則: `<.penファイル名のステム>-<Node名 or Node ID短縮>-<YYYYMMDD-HHMMSS>.png`（例: `login.pen` の `header` Node → `snapshots/login-header-20260627-153045.png`）。タイムスタンプ込みにすることで `snapshots/` 内も同時実行で衝突しない
- 新規Nodeが親コンテナ内に追加された場合、親Node IDも対象に加えると配置確認しやすい
- **ファイル全体のエクスポート（エージェントモードの `--export`）は原則使わない**。ユーザーが明示的に全体画像を要求した場合のみ `pencil --in <path> --export <全体画像のpath> --export-scale 2` を補助的に使う

## ルール6: 実行結果をユーザーに伝える

`.pen` の中身は直接確認できないため、最終報告に必ず含めます:

- 実行したコマンド（エージェントモードのCLIと、インタラクティブモードのheredoc）
- 編集したと判定したNode（IDと、可能なら名前・type）
- 更新した `.pen` ファイルの絶対パス
- 出力したNode単位スクリーンショット画像の絶対パス（編集Nodeごと）

# 標準ワークフロー

1. **前提確認**: `pencil version`、`pencil status`
2. **対象ファイル確認**: 指定された `.pen` が存在するか
3. **作業ディレクトリ確保**: `WORK_DIR="$(mktemp -d -t pencil-edit-XXXXXX)"` と `trap 'rm -rf "$WORK_DIR"' EXIT`
4. **`snapshots/` 準備**: `mkdir -p <.penと同じディレクトリ>/snapshots`
5. **編集前スナップショット**: `get_editor_state()` → `${WORK_DIR}/before.json`
6. **編集実行**: `pencil --in <path> --out <path> --prompt "<指示>" > "${WORK_DIR}/edit.log" 2>&1`（`--in`/`--out`は同一パス）
7. **編集後スナップショット**: `get_editor_state()` → `${WORK_DIR}/after.json`
8. **「実質的編集が無い」検出**: ルール4-5 の `jq` 正規化 diff で確認。該当すれば編集失敗としてルール2に戻る
9. **編集Node特定**: before/after の差分から新規/変更Node IDを抽出
10. **Node単位スクリーンショット**: `export_nodes` / `get_screenshot` で `snapshots/` にPNG出力（ファイル名はタイムスタンプ込み）
11. **報告**: 編集Nodeと出力画像パスを提示（`${WORK_DIR}` は trap で自動削除）

# 使用例: ログインページに「Forgot password?」リンクを追加

```bash
pencil status
mkdir -p designs/snapshots

WORK_DIR="$(mktemp -d -t pencil-edit-XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

# 1) 編集前 Nodeツリー
pencil interactive -i designs/login.pen -o designs/login.pen <<'EOF' > "${WORK_DIR}/before.json"
get_editor_state()
exit()
EOF

# 2) 編集（--in と --out は同じファイル）
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

before/after を比較して新規Node `forgot-link-01` を特定したら:

```bash
TS="$(date +%Y%m%d-%H%M%S)"
pencil interactive -i designs/login.pen -o designs/login.pen <<EOF
get_screenshot({ nodeId: "forgot-link-01", out: "designs/snapshots/login-forgot-link-${TS}.png", scale: 2 })
exit()
EOF
```

# 主要オプション/コマンド早見表

## エージェントモード（編集用）

| オプション | 短縮 | 用途 |
|---|---|---|
| `--in <path>` | `-i` | 入力 `.pen` ファイル（編集元） |
| `--out <path>` | `-o` | 出力 `.pen` ファイル（`--in` と同じパスを指定する） |
| `--prompt <text>` | `-p` | AIエージェントへの編集指示 |
| `--model <id>` | - | 使用モデル指定（`claude-opus-4-6` / `claude-sonnet-4-6` / `claude-haiku-4-5`） |
| `--export <path>` | - | ファイル全体の画像出力（本スキルでは原則使わない） |
| `--export-scale <n>` | - | エクスポート時のスケール（同上） |

## インタラクティブモード（Node取得・スクショ用）

起動オプション: `--in / -i <path>`、`--out / -o <path>`（ヘッドレス時必須）、`--help / -h`

シェル内ツール:
- `get_editor_state()` — Nodeツリーやメタデータの取得
- `get_screenshot(...)` — 単一NodeをPNGレンダリング
- `export_nodes(...)` — 複数NodeをPNG/JPEG/WEBP/PDFへエクスポート
- `snapshot_layout(...)` — レイアウトのスナップショット
- `batch_get(...)` / `batch_design(...)` — 複雑な取得/編集の一括処理
- `get_variables()` / `get_guidelines()` — 変数・ガイドラインの取得
- `save()` — 編集結果を `.pen` に書き出す（読み取り目的なら省略）
- `exit()` — シェル終了

# トラブルシューティング

- **`pencil: command not found`**: `npm install -g @pencil.dev/cli` を案内（Node.js 18以上必要）
- **認証エラー**: `pencil login`、または `PENCIL_CLI_KEY` 環境変数を設定
- **`-o` が必須エラー**: ヘッドレス実行では `-o` 必須。`-i` と同じパスを指定し、`save()` を呼ばなければ変更は永続化されない
- **`get_screenshot` / `export_nodes` の引数名エラー**: 出力先パラメータ名（`out` / `path` / `output` 等）や `scale` / `format` はドキュメント未記載。`pencil interactive --help` で確認して合わせる
- **編集Nodeが特定できない**（idが再採番される/大規模変更）: 影響を受けた最上位フレーム/コンポーネントを代表として1つエクスポートし、ユーザーに確認を求める
- **`.pen` ファイルが見つからない**: パスを再確認。新規作成希望なら `--in` を省略
- **想定と違う編集結果**: `--prompt` をより具体的に書き直して再実行。`.pen` は上書きされるため、重要な編集前にはユーザーに git コミット等のバックアップを促す
- **編集したはずなのに小数点正規化（例: `13.995000000000001` → `13.995`）だけが残っている**: heredoc経由の `batch_design` でJSON引数が壊れ、`save()` だけ走った典型的な事故。順にチェック:
  1. `<<EOF` で開いていないか → `<<'EOF'` に切り替える
  2. `echo` で組み立てた値を埋め込んでいないか → `jq -Rs .` か `printf '%s'` に置き換える
  3. 実改行を含むテキストを直接書いていないか → リテラル `\n` の2文字で書く
  4. ルール2のセルフチェックで最終文字列を `cat` で目視する
  5. ルール4-5 の正規化 diff で「数値正規化だけ」でないことを確認してから報告する
