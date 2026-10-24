#!/usr/bin/env bash
set -euo pipefail

REPO="getty104/claude-code-marketplace"
MARKETPLACE="getty104"

if ! command -v claude >/dev/null 2>&1; then
  echo "claude コマンドが見つかりません。先に Claude Code をインストールしてください。" >&2
  exit 1
fi

if claude plugin marketplace list 2>/dev/null | grep -q "$MARKETPLACE"; then
  claude plugin marketplace update "$MARKETPLACE"
else
  claude plugin marketplace add "$REPO"
fi

plugins=$(claude plugin list --available --json | grep -o "\"pluginId\": *\"[^\"]*@${MARKETPLACE}\"" | sed 's/.*"\([^"]*\)"$/\1/')

if [ -z "$plugins" ]; then
  echo "インストール可能なプラグインが見つかりません。" >&2
  exit 1
fi

for plugin in $plugins; do
  echo "Installing $plugin"
  claude plugin install "$plugin"
done
