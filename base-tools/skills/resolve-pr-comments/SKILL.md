---
name: resolve-pr-comments
description: GitHub PRの未解決Review threadsを一括Resolveします。
model: haiku
context: fork
---

# Resolve PR Comments

GitHubのプルリクエスト（PR）における未解決のレビューコメントを一括でResolveします。

> **呼び出し側への必須ルール**: 本スキルは `context: fork` のサブエージェントとして起動する場合でも、**絶対にバックグラウンド実行しないこと**。`Agent` ツール経由で呼び出す場合は **既定が `run_in_background: true`（バックグラウンド）** のため、**必ず `run_in_background: false` を明示指定** すること。`Skill` ツール経由の場合も `run_in_background: true` を指定してはならない（既定は同期）。呼び出し元（`fix-review-point` — `claude-task-worker` の `cc-fix-onetime` から自動起動される）は本スキルが同期的に Resolve 処理を完了したことを確認してから、コールバックコメントや再レビュー依頼に進む設計であり、バックグラウンド化すると Resolve 未完了のまま `cc-fix-onetime` が外れて次のワーカー起動に進んでしまう。

# Instructions

## 実行モードの制約: Bashをバックグラウンド実行しないこと

本スキルは `context: fork` によりサブエージェントとして起動されるが、**内部で呼び出す `Bash` は絶対にバックグラウンド実行しないこと**。具体的には次を守る。

- `Bash` ツール呼び出し時に `run_in_background: true` を指定しない。`resolve-pr-comments.sh` の GraphQL mutation 完了を stdout で確認してから次の処理に進む
- シェルコマンド末尾に `&` を付けたり、`nohup` / `disown` / `setsid` などでプロセスをデタッチしたりしない

**理由**: 本スキルは呼び出し元へ「Resolve 完了」を同期返却する契約になっており、バックグラウンド化すると `gh api` の GraphQL mutation 完了前に制御が戻り、`fix-review-point` は「Resolve が完了した」と誤認して次のフェーズ（コールバックコメント投稿・ラベル遷移）に進んでしまう。結果として、未 Resolve のまま `cc-fix-onetime` が外れて `triage-pr` ワーカーが同じ PR を再度拾い、無限ループになる。

以下のコマンドでResolveしていないレビューコメントをResolveします。

```
bash ${CLAUDE_SKILL_DIR}/scripts/resolve-pr-comments.sh
```
