# Playwright MCP での認証

ログイン操作を `aac run` 配下のスクリプトで行い、Playwright MCP は同じブラウザに CDP で接続してログイン済みのタブを操作する。パスワードは MCP のツール呼び出しにも、ファイルにも出ない。

```
① Playwright 同梱の Chromium を --remote-debugging-port=9222 で起動
② aac run ... -- node scripts/cdp-login.cjs ...   （CDP 接続 → 入力・送信 → 切断。タブは残る）
③ Playwright MCP に PLAYWRIGHT_MCP_CDP_ENDPOINT=http://localhost:9222 を渡す → ①の Chromium のログイン済みタブを操作
```

ブラウザは①の Chromium 1つだけで、②のスクリプトと③の MCP が同じ Chromium を操作する。MCP の起動引数は変えないので、claude-task-worker が登録する `playwright` サーバー（`@playwright/mcp --headless --browser chromium`）をそのまま使える。`@playwright/mcp` 0.0.83 で、この引数のまま環境変数だけで①のタブが見えることを確認済み。

## 禁止事項

- `browser_type` / `browser_fill_form` / `browser_evaluate` / `browser_run_code_unsafe` でパスワードや TOTP を入力しない（引数が会話に残る）
- ログインフォームに値が入った状態で `browser_snapshot` / `browser_take_screenshot` を取らない
- ログイン後も、個人情報が表示される画面のスナップショットは必要最小限にする
- 決済・注文・送信などの取り消せない操作は、実行前に毎回ユーザーに確認する
- 認証情報の要求（手順3）の前に、手元で承認画面が出ることをユーザーに伝える

## 1. CDP 付きで Chromium を起動する

```shell
PROFILE="${TMPDIR:-/tmp}/agent-access-cdp-profile"
rm -rf "$PROFILE" && mkdir -m 700 "$PROFILE"
CHROME=$(node -e "console.log(require('playwright').chromium.executablePath())")
NO_SANDBOX=$([ "$(id -u)" = 0 ] && echo --no-sandbox)
"$CHROME" --headless=new $NO_SANDBOX --remote-debugging-port=9222 \
  --user-data-dir="$PROFILE" about:blank >/dev/null 2>&1 &
```

- **実行場所**: CDP ポートに届くプロセスはブラウザを完全に操作でき、ログイン済みのセッションも使える。localhost に限定していても、同じホスト上の別プロセスからは接続できる。共有ホストでは実行せず、使い捨てのコンテナや専用 VM で実行する。ポートを localhost 以外に公開しない
- **サンドボックス**: 通常は Chromium のサンドボックスを有効にしたまま起動する。root で動くコンテナでは Chromium がサンドボックスなしでないと起動しないため、そのときだけ `--no-sandbox` を付ける（上のコマンドは root のときだけ付ける）。この場合はコンテナが唯一の隔離になるので、使い捨てのコンテナに限る
- **プロファイル**: ログイン済みの Cookie が残るので、起動のたびに作り直し、後片付けで必ず削除する。シェル変数は次のコマンドに引き継がれないため、決まったパスを使う

## 2. Playwright MCP を①の Chromium につなぐ

Playwright MCP は、何も指定しなければ自前のブラウザを起動するので、ログイン済みのタブは見えない。MCP サーバーを別に登録せず、既存の `playwright` サーバー（claude-task-worker が登録するものなど）に環境変数 `PLAYWRIGHT_MCP_CDP_ENDPOINT` を渡して、①の Chromium につなぐ。起動引数に `--cdp-endpoint` がなければ、この環境変数が使われる（`--headless` と `--browser chromium` は CDP 接続では使われない）。

環境変数は、プロジェクトの `.claude/settings.json` の `env` で渡す。

```json
{
  "env": {
    "PLAYWRIGHT_MCP_CDP_ENDPOINT": "http://localhost:9222"
  }
}
```

- 設定を反映するには MCP サーバーの起動し直しが必要。エージェントからはできないので、ユーザーに `/mcp` での再接続か、セッションの再起動をお願いする。再起動した場合は、①の Chromium を起動し直してから続ける
- この環境変数がある間、`playwright` サーバーのブラウザ操作は常に①の Chromium を使う。①を起動していないとブラウザ操作が失敗するので、使い終わったら `env` から消すか、ブラウザ操作の前に必ず①を起動する
- 起動引数で `--cdp-endpoint` を指定しているサーバーでは引数が優先されるので、その値を `http://localhost:9222` にそろえる

## 3. aac run 配下でログインする

まずスナップショットでログインフォームのセレクタを調べる（値はまだ入っていないので問題ない）。その後、次を実行する。

```shell
aac run --domain www.example.com --env-all -- \
  node "${CLAUDE_PLUGIN_ROOT}/skills/agent-access/scripts/cdp-login.cjs" \
  https://www.example.com/login '#username' '#password' 'button[type=submit]'
```

- 引数: `<ログインURL> <ユーザー名欄> <パスワード欄> <送信ボタン> [TOTP欄] [TOTP送信ボタン]`
- `CDP_ENDPOINT` で接続先を変更できる（デフォルト `http://localhost:9222`）
- 出力はログイン後の URL の origin と path だけ（クエリとフラグメントは出さない）。ログインページに戻っていなければ成功と判断する
- 成功・失敗にかかわらず、終了時にパスワード欄が残っていれば空にする（MCP のスナップショットにパスワードが写らないようにするため）
- `playwright` はグローバルインストールを `require` で読み込む。見つからない場合は `NODE_PATH=$(npm root -g)` を付ける

### TOTP（二段階認証）がある場合

`[TOTP欄]` を渡すと、パスワードの送信後に TOTP 欄が現れるのを待ち、`AAC_TOTP` から生成したワンタイムコードを入力して送信する。

```shell
aac run --domain www.example.com --env-all -- \
  node "${CLAUDE_PLUGIN_ROOT}/skills/agent-access/scripts/cdp-login.cjs" \
  https://www.example.com/login '#username' '#password' 'button[type=submit]' \
  'input[autocomplete=one-time-code]' 'button[type=submit]'
```

- `[TOTP送信ボタン]` を省略すると、TOTP 欄で Enter を押して送信する
- コードの有効期限が残り3秒未満なら、次のコードに切り替わるまで待ってから入力する
- 保管庫の項目に TOTP がない（`AAC_TOTP` が空）場合は exit 2 で止まる
- TOTP 欄のセレクタが分からない場合は、まず TOTP 欄の引数なしで実行する。タブが TOTP の入力画面で止まるので、スナップショットでセレクタを調べてから、TOTP 欄の引数付きで実行し直す
- コードの生成は `scripts/totp.cjs` が行う。RFC 6238 準拠で、otpauth URI（digits / period / algorithm 指定を含む）と Base32 の鍵の両方に対応している。Steam Guard 形式（`steam://`）には対応していない

### メールや SMS の認証コードがある場合

1. TOTP 欄の引数なしで `cdp-login.cjs` を実行する。パスワードの送信後、タブはコード入力画面で止まる
2. SKILL.md の手順6に従い、メール（または SMS）からコードを取り出す
3. `browser_tabs` でそのタブを選び、`browser_snapshot` で入力欄を調べてから、`browser_type` でコードを入力して送信する。認証用リンクの場合は `browser_navigate` で開く

認証コードは使い捨ての値なので、MCP のツールで入力してよい。パスワードと TOTP の鍵は、引き続き MCP のツールでは扱わない。

## 4. MCP で操作する

`browser_tabs`（`action: list`）でログイン後のタブを探し、`select` で選んでから操作する。ログインが切れたら、手順3をもう一度実行する。

## 対応できないケース

| ケース | 理由 |
|---|---|
| パスキー | Agent Access で値を受け取れない |
| メールや SMS のコードで、読み取れるツールがない | ユーザーにコードを教えてもらう |
| Steam Guard 形式の TOTP | `totp.cjs` が未対応 |
| CAPTCHA、追加の本人確認 | クラウドの IP アドレスから自動ではログインできないことがある。ユーザーに伝えて中止する |
| ユーザー名とパスワードが別画面のフォーム | `cdp-login.cjs` は1画面のフォームを前提にしている |

## 後片付け

```shell
pkill -f -- '--remote-debugging-port=922[2]'
rm -rf "${TMPDIR:-/tmp}/agent-access-cdp-profile"
```
