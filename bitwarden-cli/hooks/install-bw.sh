#!/usr/bin/env sh
[ "$CLAUDE_CODE_REMOTE" = true ] || exit 0
command -v bw >/dev/null 2>&1 && exit 0
npm install -g @bitwarden/cli@2026.10.1 >/dev/null 2>&1
command -v bw >/dev/null 2>&1 && exit 0
echo "Bitwarden CLI のインストールに失敗しました" >&2
exit 1
