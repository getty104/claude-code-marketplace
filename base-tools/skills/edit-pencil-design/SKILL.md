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

## ルール1: 編集モードの選択（エージェント / `interactive` どちらも可）

このスキルでの `.pen` 編集は **次のどちらでも可** です。タスクに応じて使い分けます。

- **エージェントモード** `pencil --in --out --prompt "<自然言語指示>"`
  - 自然言語で「ここを直して」と任せたい時に使う
  - 大きめのリファイン、レイアウト調整、複数Nodeにまたがる修正など
- **インタラクティブモードでの構造編集** `pencil interactive` 内で `batch_design({...})` を直接呼ぶ
  - 「特定NodeのプロパティをこのJSONに置換」のような決定論的な編集に使う
  - エージェントモードよりも結果が予測可能。差分も追いやすい

**ただし** インタラクティブモード経由の編集は、heredoc/シェルの改行展開を間違えるとサイレントに失敗します。**ルール2の heredoc 安全規則を必ず守ってください**。それさえ守れば `batch_design` 編集は完全に安全です。

どちらのモードでも、既存ファイルを更新する用途なので、必ず `--in` と `--out` に**同じ `.pen` ファイルのパス**を指定します。

```bash
# エージェントモード
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

### heredoc / シェルの改行展開を正しく扱う（重要）

`pencil interactive` に長いJSON引数（特に `batch_design({...})`）を heredoc で流すとき、シェルが文字列内の `\n` をどう解釈するかを把握していないと、JSON引数が壊れて Pencil 側がパースエラーをサイレントに無視し、`save()` だけが走って小数点正規化（`13.995000000000001` → `13.995`）のような無害な差分だけがディスクに残ります。**過去に実害ありの事故パターンなので必読**。

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
   pencil interactive -i path/to/design.pen -o path/to/design.pen <<'EOF'
   batch_design({
     ops: [
       { type: "update", id: "title-01", props: { text: "Hello\nWorld" } }
     ]
   })
   save()
   exit()
   EOF
   ```

   `"Hello\nWorld"` の `\n` は2文字のままPencilに届き、Pencil側がJSON文字列としてパースしたあと、テキスト値内の改行として正しく扱われます。

2. **動的な値を埋め込む必要があるなら `jq` でJSONエンコード**してから heredoc に差し込みます。`echo "{\"text\": \"$user_input\"}"` のような自前組み立ては絶対に避けます（`$user_input` に改行・ダブルクォート・バックスラッシュが含まれた瞬間に壊れる）。

   ```bash
   TEXT_JSON=$(jq -Rs . <<< "Hello
   World")
   # → "Hello\nWorld" という、正しくエスケープされたJSON文字列リテラルになる

   IDS_JSON=$(jq -nc --argjson ids '["title-01"]' '$ids')

   pencil interactive -i path/to/design.pen -o path/to/design.pen <<EOF
   batch_design({
     ops: [
       { type: "update", id: ${IDS_JSON}[0], props: { text: ${TEXT_JSON} } }
     ]
   })
   save()
   exit()
   EOF
   ```

   `<<EOF`（クォート無し）なら `${TEXT_JSON}` が展開されますが、`jq -Rs .` が改行・特殊文字を **JSONエスケープ済みの文字列**（前後にダブルクォート付き）に変換してくれているので、heredoc内に貼り込んでも構文が壊れません。

3. **`echo` を使わない、`printf '%s\n'` または `print -r --` を使う**。heredocを使わずに引数文字列を組み立てたい場面では、`echo` は禁止です。

   ```bash
   # NG (zshで\nが実改行に化けてJSONが壊れる)
   ARGS=$(echo '{ "text": "Hello\nWorld" }')

   # OK
   ARGS=$(printf '%s' '{ "text": "Hello\nWorld" }')
   # OK (zsh)
   ARGS=$(print -r -- '{ "text": "Hello\nWorld" }')
   ```

4. **JSON値として改行が必要なら、エディタ上では `\n` の2文字で書く**。heredoc本文に「実際の改行を含むテキスト」を書きたい誘惑がありますが、JSON文字列リテラルは本来改行を含めず `\n` で表現するのが正しいJSONです。シェル経路で改行が化けないかを毎回意識する負担を消すためにも、リテラル `\n` で書く規約に統一します。

   ```bash
   pencil interactive -i path/to/design.pen -o path/to/design.pen <<'EOF'
   batch_design({ ops: [{ type: "update", id: "t1", props: { text: "line1\nline2" } }] })
   save()
   exit()
   EOF
   ```

#### 失敗パターンを早く検出するためのセルフチェック

heredoc を組み立てた直後、Pencilに流す前に「シェルが解釈した最終文字列」を `cat` で目視できると事故が減ります。

```bash
cat > "${WORK_DIR}/cmds.txt" <<'EOF'
batch_design({ ops: [{ type: "update", id: "t1", props: { text: "line1\nline2" } }] })
save()
exit()
EOF
cat "${WORK_DIR}/cmds.txt"   # JSON文字列リテラル内の \n が2文字のまま残っていることを目視
pencil interactive -i path/to/design.pen -o path/to/design.pen < "${WORK_DIR}/cmds.txt"
```

`cat` 出力内に JSON文字列リテラル内のはずだった `\n` が **実改行になっていたら即失敗**です。`<<'EOF'`（シングルクォート付き）に修正してやり直します。

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

5. **「実質的な編集が無い」ケースの検出 → 編集失敗扱いにする**

   差分が次のような「無害な表現正規化だけ」だった場合は、**Pencil側でJSONパースエラーが起きて構造変更が一切適用されず、`save()` だけが走った可能性が極めて高い**ので、編集失敗としてユーザーに報告し、再実行します。これがルール2の改行展開トラブルの典型的な観測像です。

   - Node ID の追加・削除が無い
   - Node の type / name / children の構造変化が無い
   - 数値属性のフォーマットだけが変わっている（例: `13.995000000000001` → `13.995`、`100.0` → `100`、`-0` → `0`）
   - その他の浮動小数点表記の正規化のみ

   実用的なチェックは `jq` で「数値の文字列化」を揃えてから差分を取る方法です。

   ```bash
   # 数値を統一フォーマットに正規化してから比較（表現の揺れを潰す）
   jq -S 'walk(if type == "number" then tonumber|tostring|tonumber else . end)' \
     "${WORK_DIR}/before.json" > "${WORK_DIR}/before.norm.json"
   jq -S 'walk(if type == "number" then tonumber|tostring|tonumber else . end)' \
     "${WORK_DIR}/after.json"  > "${WORK_DIR}/after.norm.json"

   if diff -q "${WORK_DIR}/before.norm.json" "${WORK_DIR}/after.norm.json" >/dev/null; then
     echo "編集失敗の疑い: 構造に有意な差分なし。heredocのJSON引数が壊れていないかルール2を再確認してください" >&2
     exit 1
   fi
   ```

   この検証はワークフロー6→7の間（編集Node特定の直前）に必ず通します。失敗が出たら「heredocのJSON引数が壊れていないか」「`<<'EOF'` でクォートしているか」「`echo` で組み立てていないか」をルール2に戻って確認します。

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
8. **「実質的編集が無い」検出**: ルール4-5 の `jq` 正規化 diff で「数値正規化だけの差分」になっていないかを確認。なっていれば編集失敗としてルール2に戻り、heredoc/echo の改行展開トラブルを疑う
9. **編集Node特定**: `${WORK_DIR}/before.json` と `${WORK_DIR}/after.json` の差分から新規/変更されたNode IDを抽出
10. **Node単位スクリーンショット**: `pencil interactive` のheredocで `export_nodes` または `get_screenshot` を呼び、`snapshots/` 配下にPNG出力（出力先パスはタイムスタンプ込みのファイル名にすることで `snapshots/` 内も同時実行で衝突しない）
11. **報告**: 編集Nodeと出力画像パスをユーザーへ提示（`trap` により `${WORK_DIR}` は自動削除される）

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
- **編集したはずなのに `.pen` がほぼ変わっていない / 小数点フォーマットの正規化（例: `13.995000000000001` → `13.995`）だけが残っている**: `pencil interactive` で `batch_design` を heredoc 経由で呼んだ際にJSON引数が壊れ、Pencil側がパースエラーをサイレント無視して `save()` だけ走った典型的な事故。次を順にチェック:
  1. heredocを `<<EOF` で開いていないか → `<<'EOF'`（シングルクォート）に切り替える
  2. JSON文字列内に `echo` で組み立てた値を埋め込んでいないか → `jq -Rs .` か `printf '%s' ...` に置き換える
  3. heredoc内に「実改行を含むテキスト」を直接書いていないか → JSON文字列リテラルとして `\n` の2文字で書く
  4. ルール2の「シェルが解釈した最終文字列を `cat` で目視」セルフチェックを通し、`\n` が実改行に化けていないことを確認
  5. ルール4-5 の `jq` 正規化 diff で「数値正規化だけ」になっていないことを確認してから報告する
