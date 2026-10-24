---
name: agent-access
description: AIエージェントが Bitwarden Agent Access（aac CLI）を使い、ユーザーの Bitwarden 保管庫から承認付きで認証情報を受け取り、パスワードを会話コンテキストに出さずにコマンドやブラウザログインへ注入する手順。ALWAYS invoke this skill when the user mentions Agent Access, aac, Bitwarden から認証情報を取得, 保管庫のパスワードを使ってログイン, クラウドセッションで Bitwarden, or ブラウザツールで認証. パスキーは扱えない。
argument-hint: "[domain | vault item id]"
---

# Agent Access

エージェントは `aac connect` / `aac run` で認証情報を要求する。要求は中継サーバー経由の E2E 暗号化トンネルでユーザーの手元の `aac listen` に届き、ユーザーが承認したものだけが返ってくる。

- エージェントが行うこと: `aac` の導入、ペアリング、認証情報の要求、取得した値の注入
- ユーザーにお願いすること: 手元での `aac listen` の起動、保管庫のロック解除、ペアリングトークンの共有、要求ごとの承認

参考: https://github.com/bitwarden/agent-access （early preview。プロトコルは変わりうる）。中継サーバー `wss://ap.lesspassword.dev` には、クラウドセッションの HTTPS プロキシ越しでも接続できる。

## 絶対に守ること

- **秘密の値を会話コンテキストに出さない。** 取得は必ず `aac run` で子プロセスの環境変数に注入する。`aac connect --domain ... --output json` は password を stdout に出すので使わない
- 確認出力は長さや有無だけにする（例: `echo "password_len=${#AAC_PASSWORD}"`）。値そのもの、`env`、`set -x` は禁止
- 認証情報をファイルに書かない。ブラウザで使う場合は、ブラウザツール別のリファレンスに従う
- ユーザーに保管庫のパスワードやマスターパスワードを尋ねない。ペアリングトークン以外を貼ってもらわない

## 1. エージェント環境に aac を導入する

```shell
command -v aac || {
  mkdir -p ~/.local/bin
  curl -sSL https://github.com/bitwarden/agent-access/releases/latest/download/aac-linux-x86_64.tar.gz | tar xz -C ~/.local/bin
}
aac --version
```

macOS では `aac-macos-aarch64.tar.gz` / `aac-macos-x86_64.tar.gz` を使う。

## 2. ユーザーにローカルのセットアップをお願いする

すでにペアリング済み（`aac connections list` に接続がある）で、ユーザーの `aac listen` が動いていれば省略する。そうでなければ、次の文面で依頼する。

> 認証情報を取得するため、手元の PC で次の準備をお願いします。
> 1. [Bitwarden CLI](https://bitwarden.com/help/cli/)（`bw`）と [aac](https://github.com/bitwarden/agent-access#installation) をインストールする
> 2. 同じターミナルで次を実行する
>    ```shell
>    bw login                            # 未ログインの場合のみ
>    export BW_SESSION=$(bw unlock --raw)
>    aac listen
>    ```
> 3. 画面に表示されたペアリングトークン（`ABC-DEF-GHI` のような形式）を教えてください
>
> この後、私が認証情報を要求するたびに手元に承認画面が出ます。`[y]` で承認してください（`[a]` を選ぶと10分間は承認なしで渡ります）。

動作確認だけの場合は、`aac listen --provider example` を案内する。example.com のサンプル認証情報しか返さず、実際の保管庫には触れない。

## 3. ペアリングする

```shell
aac connect --token <ペアリングトークン> --domain example.com --output json
```

- 接続は `~/.access-protocol/` にキャッシュされ、以後トークンは不要になる。残したくない場合は `--ephemeral-connection` を付ける
- 接続が複数あると `Multiple cached connections found` になる。`aac connections list` で fingerprint を確認し、`--session <fingerprint か一意な prefix>` を付ける

## 4. 認証情報を要求して使う

```shell
# フィールドを個別の環境変数に割り当てる
aac run --domain example.com --env DB_USER=username --env DB_PASSWORD=password -- psql

# 全フィールドを AAC_ プレフィックスで注入（AAC_USERNAME, AAC_PASSWORD, AAC_TOTP, AAC_URI, ...）
aac run --id <vault-item-id> --env-all -- ./deploy.sh

# 取得できたかだけ確認する
aac run --domain example.com --env-all -- sh -c 'echo "username_len=${#AAC_USERNAME} password_len=${#AAC_PASSWORD} totp=$([ -n "$AAC_TOTP" ] && echo yes || echo no)"'
```

- 要求を出す前に「手元で承認画面が出るので承認してください」と伝える
- 承認待ちのデフォルトタイムアウトは120秒（`--timeout` で変更可）
- フィールド: `username`, `password`, `totp`, `uri`, `notes`, `domain`, `credential_id`
- `totp` はワンタイムコードではなく **TOTP シークレット**。コードはスクリプト内で生成する

## 5. ブラウザでログインする

ブラウザツールでパスワードを直接入力すると、ツール呼び出しの引数として値が会話に残る。**ログイン操作だけを `aac run` 配下のスクリプトで行い、ブラウザツールにはログイン済みのブラウザを渡す。**

| ブラウザツール | リファレンス |
|---|---|
| Playwright MCP | [references/playwright-mcp.md](references/playwright-mcp.md) |

## トラブルシューティング

エージェント側に返る拒否は、理由に関係なくすべて `Request denied` になる。**応答までの時間で切り分け、ユーザーに確認をお願いする。**

| 症状 | 原因 | ユーザーへのお願い・対処 |
|---|---|---|
| 数秒で `Request denied` | 手元の `bw get item <検索語>` が失敗し、承認画面を出さずに自動拒否された | 手元の `aac listen` に出ている表示を教えてもらい、下の3つで切り分ける |
| ↳ 一致が複数ある | `bw get item` は一致がちょうど1件のときしか成功しない | `bw list items --search <語> \| jq -r '.[] \| "\(.id)  \(.name)"'` を実行して ID を教えてもらい、`--id` で要求し直す |
| ↳ ID 指定でも拒否 | `aac listen` が持つ保管庫のセッションが古い。この状態の `bw` はロックではなく `Not found` を返す | `export BW_SESSION=$(bw unlock --raw)` の後で `aac listen` を起動し直すか、`/unlock` をやり直してもらう |
| ↳ ログイン以外の項目 | `login` を持たない項目（カード、メモなど）は対象外 | 対象外であることを伝える |
| 約120秒でタイムアウト | 手元で承認されていない | 承認画面を確認してもらう |
| `Rendezvous resolution failed` | ペアリングトークンが無効、期限切れ、または使用済み | 新しいトークンを発行してもらう |
| `Multiple cached connections found` | 複数回ペアリングした | `--session` で指定する。不要なら `aac connections clear connections --client-type remote` で消し、再ペアリングする |

## できないこと

- **パスキー**: プロトコルにフィールドがなく、Bitwarden プロバイダーも読まない
- メールや SMS で届くワンタイムコード

## 後片付け

- エージェント側: `aac connections clear connections --client-type remote`
- ユーザーへのお願い: 作業が終わったら、手元の `aac listen` を終了してもらう
