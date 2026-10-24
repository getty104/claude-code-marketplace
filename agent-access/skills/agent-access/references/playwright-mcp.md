# Playwright MCP での認証

ログイン操作を `aac run` 配下のスクリプトで行い、Playwright MCP は同じブラウザに CDP で接続してログイン済みのタブを操作する。パスワードは MCP のツール呼び出しにも、ファイルにも出ない。

```
① Chromium を --remote-debugging-port=9222 で起動
② aac run ... -- node scripts/cdp-login.cjs ...   （CDP 接続 → 入力・送信 → 切断。タブは残る）
③ Playwright MCP を --cdp-endpoint http://localhost:9222 で起動 → ログイン済みタブを操作
```

`@playwright/mcp` 0.0.83 で、③からログイン済みタブが見えることを確認済み。

## 禁止事項

- `browser_type` / `browser_fill_form` / `browser_evaluate` / `browser_run_code_unsafe` でパスワードや TOTP を入力しない（引数が会話に残る）
- ログインフォームに値が入った状態で `browser_snapshot` / `browser_take_screenshot` を取らない
- ログイン後も、個人情報が表示される画面のスナップショットは必要最小限にする
- 決済・注文・送信などの取り消せない操作は、実行前に毎回ユーザーに確認する

## 1. CDP 付きで Chromium を起動する

```shell
CHROME=$(node -e "console.log(require('playwright').chromium.executablePath())")
"$CHROME" --headless=new --no-sandbox --remote-debugging-port=9222 \
  --user-data-dir="$(mktemp -d)" about:blank >/dev/null 2>&1 &
```

- CDP ポートに届く人はブラウザを完全に操作できる。localhost 以外に公開しない
- `--user-data-dir` は使い捨てのディレクトリにする（ログイン済みの Cookie が残るため）

## 2. Playwright MCP を CDP 接続で登録する

既存の Playwright MCP（`--headless --browser chromium` など）は自前のブラウザを起動するため、ログイン済みのブラウザは見えない。CDP に接続する別名のサーバーをプロジェクトの `.mcp.json` に追加する。

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

MCP の設定は読み込み直しが必要（セッションの再起動になることがある）。その場合は、①のブラウザを起動した状態で再開する。

## 3. aac run 配下でログインする

まずスナップショットでログインフォームのセレクタを調べる（値はまだ入っていないので問題ない）。その後、次を実行する。

```shell
aac run --domain www.example.com --env-all -- \
  node ${CLAUDE_PLUGIN_ROOT}/skills/agent-access/scripts/cdp-login.cjs \
  https://www.example.com/login '#username' '#password' 'button[type=submit]'
```

- 引数: `<ログインURL> <ユーザー名欄> <パスワード欄> <送信ボタン>`
- `CDP_ENDPOINT` で接続先を変更できる（デフォルト `http://localhost:9222`）
- 出力はログイン後の URL だけ。ログインページに戻っていなければ成功と判断する
- `playwright` はグローバルインストールを `require` で読み込む。見つからない場合は `NODE_PATH=$(npm root -g)` を付ける

## 4. MCP で操作する

`browser_tabs`（`action: list`）でログイン後のタブを探し、`select` で選んでから操作する。ログインが切れたら、手順3をもう一度実行する。

## 対応できないケース

| ケース | 理由 |
|---|---|
| パスキー、メールや SMS のコード | Agent Access で値を受け取れない |
| TOTP | `cdp-login.cjs` は未対応。`AAC_TOTP`（シークレット）からコードを生成する処理を追加する必要がある |
| CAPTCHA、追加の本人確認 | クラウドの IP アドレスから自動ではログインできないことがある。ユーザーに伝えて中止する |
| ユーザー名とパスワードが別画面のフォーム | `cdp-login.cjs` は1画面のフォームを前提にしている |

## 後片付け

```shell
pkill -f -- '--remote-debugging-port=9222'
```

`--user-data-dir` に指定したディレクトリも削除する。
