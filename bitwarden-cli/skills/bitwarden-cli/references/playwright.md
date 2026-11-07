# Playwright での認証（CDP モード）

Chrome を CDP モードで起動し、ログイン操作だけを `scripts/cdp-login.cjs` が行う。スクリプトは保管庫の値を bw から直接受け取ってフォームに入力するので、エージェントは認証情報の中身を一切見ない。Playwright MCP は同じ Chrome に CDP で接続し、ログイン済みのタブを操作する。

```
① Chrome を --remote-debugging-port=9222 で起動
② node scripts/cdp-login.cjs <item-id> ...   （CDP 接続 → 入力・送信 → 切断。タブは残る）
③ Playwright MCP を --cdp-endpoint http://localhost:9222 で起動 → ログイン済みタブを操作
```

## 禁止事項

- `browser_type` / `browser_fill_form` / `browser_evaluate` / `browser_run_code_unsafe` でパスワードや TOTP を入力しない（引数が会話に残る）
- ログインフォームに値が入った状態で `browser_snapshot` / `browser_take_screenshot` を取らない
- Playwright を自前のブラウザ（CDP 以外）で起動してログインしない
- 決済・注文・送信などの取り消せない操作は、実行前に毎回ユーザーに確認する

## 1. CDP モードで Chrome を起動する

```shell
PROFILE="${TMPDIR:-/tmp}/bitwarden-cli-cdp-profile"
rm -rf "$PROFILE" && mkdir -m 700 "$PROFILE"
CHROME=$(command -v google-chrome || command -v google-chrome-stable || node -e "console.log(require('playwright').chromium.executablePath())")
NO_SANDBOX=$([ "$(id -u)" = 0 ] && echo --no-sandbox)
"$CHROME" --headless=new $NO_SANDBOX --remote-debugging-port=9222 \
  --user-data-dir="$PROFILE" about:blank >/dev/null 2>&1 &
```

- CDP ポートに届くプロセスはブラウザを完全に操作できる。共有ホストでは実行せず、ポートを localhost 以外に公開しない
- `--no-sandbox` は root で動く使い捨てコンテナのときだけ付ける
- プロファイルにはログイン済みの Cookie が残るので、起動のたびに作り直し、後片付けで削除する

## 2. Playwright MCP を CDP 接続で登録する

プロジェクトの `.mcp.json` に追加し、ユーザーに `/mcp` での再接続かセッションの再起動をお願いする。

```json
{
  "mcpServers": {
    "playwright-cdp": {
      "command": "npx",
      "args": ["-y", "@playwright/mcp@latest", "--cdp-endpoint", "http://localhost:9222"]
    }
  }
}
```

## 3. ログインする

SKILL.md の手順1〜3（BW_SESSION の確認、ログイン、項目の検索）を済ませてから、スナップショットでログインフォームのセレクタを調べ（値はまだ入っていない）、次を実行する。

```shell
node "${CLAUDE_PLUGIN_ROOT}/skills/bitwarden-cli/scripts/cdp-login.cjs" <item-id> \
  https://www.example.com/login '#username' '#password' 'button[type=submit]'
```

- 引数: `<item-id> <ログインURL> <ユーザー名欄> <パスワード欄> <送信ボタン> [TOTP欄] [TOTP送信ボタン]`
- BW_SESSION がなければ exit 2 で止まり、bw を実行しない
- 出力はログイン後の URL の origin と path だけ。ログインページに戻っていなければ成功と判断する
- 終了時にパスワード欄が残っていれば空にする
- TOTP 欄を渡すと `bw get totp` のコードを入力する（残り3秒未満なら次のコードまで待つ）。項目に TOTP がなければ exit 2
- `CDP_ENDPOINT` で接続先を変更できる。`playwright` が見つからなければ `NODE_PATH=$(npm root -g)` を付ける

メールや SMS の認証コードは使い捨てなので、`browser_type` で入力してよい。

## 4. MCP で操作する

`browser_tabs`（`action: list`）でログイン後のタブを選んでから操作する。

## 後片付け

```shell
pkill -f -- '--remote-debugging-port=922[2]'
rm -rf "${TMPDIR:-/tmp}/bitwarden-cli-cdp-profile"
```
