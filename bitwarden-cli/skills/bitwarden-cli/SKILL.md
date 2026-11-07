---
name: bitwarden-cli
description: Bitwarden CLI（bw）を `bw login --apikey` でログインし、BW_SESSION がある場合だけ保管庫の認証情報をコマンドやブラウザログインに使う手順。BW_ 系の環境変数と保管庫の値は出力・閲覧・外部送信しない。ALWAYS invoke this skill when the user mentions Bitwarden CLI, bw コマンド, BW_SESSION, Bitwarden の保管庫からパスワードを使う, or Bitwarden でブラウザログイン.
argument-hint: "[検索語 | vault item id]"
---

# Bitwarden CLI

## 絶対に守ること

- **BW_SESSION がなければ bw を実行しない。** 手順1で未設定なら、ここで止めてユーザーに設定を依頼する
- **BW_ 系の環境変数（`BW_SESSION`, `BW_CLIENTID`, `BW_CLIENTSECRET` など）の中身を出力・閲覧・外部送信しない。** コマンドに `BW_` の名前を書かない（bw は自動で読む）。`env` / `printenv` / `set` / `export -p` / `/proc/*/environ` も使わない
- **保管庫の値（パスワード、TOTP）を会話に出さない。** `bw get password` / `bw get item` / `bw list items` を直接実行しない。必ず `scripts/bw.cjs` か `scripts/cdp-login.cjs` を使う
- `bw unlock` は `--check` 以外使わない（セッションキーが出力される）。マスターパスワードを尋ねない
- 認証情報をファイルに書かない

プラグインの PreToolUse フック（`hooks/guard-bw-env.cjs`）がこれらの一部を機械的に止める。止められたら回避せず、手順を見直す。

## 0. settings.json の deny ルールを確認する

プラグインの `settings.json` では `permissions` が効かないため、[settings.json](settings.json) の `permissions.deny` をユーザーの `~/.claude/settings.json` かプロジェクトの `.claude/settings.json` に入れておく。入っていなければ、追加してよいかユーザーに確認してから追記する。

## 1. 環境変数を確認する

```shell
sh "${CLAUDE_PLUGIN_ROOT}/skills/bitwarden-cli/scripts/check-env.sh"
```

`set` / `unset` だけを出力する。`BW_SESSION=unset` なら **ここで中止** し、次を依頼する。

> Bitwarden CLI を使うため、Claude Code を起動する環境に `BW_SESSION` を設定してください（`bw login --apikey` で使う `BW_CLIENTID` / `BW_CLIENTSECRET` も）。値は会話に貼らないでください。

## 2. API キーでログインする

```shell
bw status | node -e 'const s=JSON.parse(require("fs").readFileSync(0));console.log(s.status)'
```

- `unauthenticated` なら `bw login --apikey` を実行する（`BW_CLIENTID` / `BW_CLIENTSECRET` を自動で読む）
- その後 `bw unlock --check` で BW_SESSION が有効か確かめる。無効なら中止し、ユーザーに BW_SESSION の再発行を依頼する（BW_SESSION は発行した環境のローカルデータとだけ組になる）
- 必要に応じて `bw sync` で最新化する

## 3. 保管庫の項目を探す

```shell
node "${CLAUDE_PLUGIN_ROOT}/skills/bitwarden-cli/scripts/bw.cjs" search example.com
```

`id 名前 URI totp=yes|no` だけを出力する。複数あればユーザーにどれを使うか確認する。

## 4. コマンドに注入する

```shell
node "${CLAUDE_PLUGIN_ROOT}/skills/bitwarden-cli/scripts/bw.cjs" run <item-id> -- \
  sh -c 'some-cli login --user "$ITEM_USERNAME" --password "$ITEM_PASSWORD"'
```

- 子プロセスに `ITEM_USERNAME` / `ITEM_PASSWORD` / `ITEM_TOTP`（現在のワンタイムコード。TOTP がある項目のみ）を渡す。`BW_` 系の変数は子プロセスから取り除く
- 確認は長さだけにする（例: `sh -c 'echo "password_len=${#ITEM_PASSWORD}"'`）

## 5. ブラウザでログインする

| ブラウザツール | リファレンス |
|---|---|
| Playwright | [references/playwright.md](references/playwright.md) |
