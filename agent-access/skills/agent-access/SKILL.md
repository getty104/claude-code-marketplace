---
name: agent-access
description: Bitwarden Agent Access（aac CLI）で、ユーザーのローカルの Bitwarden 保管庫から認証情報を1件ずつ承認付きで受け取り、パスワードを会話コンテキストに出さずにコマンドやブラウザログインへ注入する。ALWAYS invoke this skill when the user mentions Agent Access, aac, Bitwarden から認証情報を取得, 保管庫のパスワードを使ってログイン, クラウドセッションで Bitwarden, or ブラウザツールで認証. パスキーは扱えない。
argument-hint: "[domain | vault item id]"
---

# Agent Access

ユーザーの手元で動く `aac listen`（Bitwarden 保管庫側）と、このセッションで動く `aac connect` / `aac run`（エージェント側）を、中継サーバー経由の E2E 暗号化トンネルでつなぎ、ユーザーが承認した認証情報だけを受け取る。

- リポジトリ: https://github.com/bitwarden/agent-access （early preview。プロトコルは変わりうる）
- 中継サーバー: `wss://ap.lesspassword.dev`（`--proxy-url` で変更可）。クラウドセッションの HTTPS プロキシ越しで接続できることを確認済み

## 絶対に守ること

- **秘密の値を会話コンテキストに出さない。** 取得は必ず `aac run` で子プロセスの環境変数に注入する。`aac connect --domain ... --output json` は password を stdout に出すので、エージェントからは使わない
- 確認出力は長さや有無だけにする（例: `echo "password_len=${#AAC_PASSWORD}"`）。値そのもの、`env`、`set -x` は禁止
- 認証情報をファイルに書かない。ブラウザ等で使う場合はブラウザツール別のリファレンスに従う
- ペアリングトークンを実保管庫で使う場合はユーザーに確認してから扱う。使い捨てだが、会話に残る

## 1. セットアップ

### エージェント側（このセッション）

```shell
command -v aac || {
  mkdir -p ~/.local/bin
  curl -sSL https://github.com/bitwarden/agent-access/releases/latest/download/aac-linux-x86_64.tar.gz | tar xz -C ~/.local/bin
}
aac --version
```

macOS は `aac-macos-aarch64.tar.gz` / `aac-macos-x86_64.tar.gz`。

### ユーザー側（手元の PC）— ユーザーに案内する

保管庫のセッションキーを古くしないため、**`BW_SESSION` を設定した同じターミナルで** `aac listen` を起動してもらう。

```shell
bw login                           # 未ログイン時のみ
export BW_SESSION=$(bw unlock --raw)
aac listen                         # 起動後に表示されるペアリングトークンを共有してもらう
```

動作確認だけなら `aac listen --provider example`（example.com のサンプル認証情報のみ）で、実保管庫に触れずに試せる。

## 2. ペアリング

```shell
aac connect --token <ペアリングトークン> --domain example.com --output json
```

- 接続は `~/.access-protocol/` にキャッシュされ、以後はトークン不要
- キャッシュを残したくない場合は `--ephemeral-connection`
- 接続が複数あると `Multiple cached connections found` になる。`aac connections list` で fingerprint を確認し、以後は `--session <fingerprint か一意な prefix>` を付ける

## 3. 認証情報を使ってコマンドを実行する

```shell
# フィールドを個別の環境変数に割り当てる
aac run --domain example.com --env DB_USER=username --env DB_PASSWORD=password -- psql

# 全フィールドを AAC_ プレフィックスで注入（AAC_USERNAME, AAC_PASSWORD, AAC_TOTP, AAC_URI, ...）
aac run --id <vault-item-id> --env-all -- ./deploy.sh

# 取得できたかだけ確認する
aac run --domain example.com --env-all -- sh -c 'echo "username_len=${#AAC_USERNAME} password_len=${#AAC_PASSWORD} totp=$([ -n "$AAC_TOTP" ] && echo yes || echo no)"'
```

- 毎回ユーザーの手元で承認が必要（`[y]` 承認 / `[a]` 承認＋10分間自動承認 / `[n]` 拒否）。実保管庫では `[y]` を勧める
- 承認待ちのデフォルトタイムアウトは120秒（`--timeout` で変更）
- フィールド: `username`, `password`, `totp`, `uri`, `notes`, `domain`, `credential_id`
- `totp` はワンタイムコードではなく **TOTP シークレット**。コードはスクリプト内で生成する

## 4. ブラウザでログインする

ブラウザツールでパスワードを直接入力すると、ツール呼び出しの引数として値が会話に残る。**ログイン操作だけを `aac run` 配下のスクリプトで行い、ブラウザツールにはログイン済みのブラウザを渡す。**

ツール別の手順:

| ブラウザツール | リファレンス |
|---|---|
| Playwright MCP | [references/playwright-mcp.md](references/playwright-mcp.md) |

## トラブルシューティング

`aac` 側から見える拒否は、理由に関係なくすべて `Request denied` になる。**応答までの時間で切り分ける。**

| 症状 | 原因 | 対処 |
|---|---|---|
| 数秒で `Request denied` | 手元の `bw get item <検索語>` が失敗し、承認画面を出さずに自動拒否された（手元には `No credential found` と出る） | 下の3つを順に確認する |
| ↳ 一致が複数 | `bw get item` は一致がちょうど1件のときしか成功しない（`More than one result was found`） | ユーザーに `bw list items --search <語> \| jq -r '.[] \| "\(.id)  \(.name)"'` で ID を出してもらい、`--id` で要求する |
| ↳ ID 指定でも拒否 | `aac listen` が持つ `BW_SESSION` が古い。この状態の `bw` はロックではなく `Not found` を返すため、`aac` は見つからないと判断する | 手元で `export BW_SESSION=$(bw unlock --raw)` をしてから `aac listen` を起動し直すか、`/unlock` をやり直してもらう |
| ↳ ログイン以外の項目 | `login` を持たない項目（カード、メモなど）は対象外 | 対象外であることを伝える |
| 約120秒でタイムアウト | 手元で承認されていない | 手元の承認画面を確認してもらう |
| `Rendezvous resolution failed` | ペアリングトークンが無効・期限切れ・使用済み | 新しいトークンを発行してもらう |
| `Multiple cached connections found` | ペアリングを複数回した | `--session` で指定するか、`aac connections clear connections --client-type remote` で消して再ペアリングする |

## できないこと

- **パスキー**: プロトコルにフィールドがなく、Bitwarden プロバイダーも読まない
- メールや SMS で届くワンタイムコード

## 後片付け

- エージェント側: `aac connections clear connections --client-type remote`
- ユーザー側: 使い終わったら `aac listen` を終了してもらう
