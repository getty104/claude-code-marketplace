---
name: create-pr
description: GitHubでPull Request（PR）を作成します。PRのdescriptionには指定されたテンプレートを使用し、必要な情報を記載します。PR作成後、PRのURLを報告します。
model: haiku
agent: general-purpose
context: fork
---

# Create Pull Request

このスキルは、GitHubでPull Request（PR）を作成するための包括的なガイダンスを提供します。

# Instructions

PRは以下のルールで作成します。

- PRのdescriptionのテンプレートは`.github/PULL_REQUEST_TEMPLATE.md`を参照し、それに従うこと
- PRのdescriptionのテンプレート内でコメントアウトされている箇所は必ず削除すること
- PRのdescriptionには`Closes [Issue番号]`と記載すること
- ghコマンドの`gh api user`で取得したユーザーをアサインしてください
