---
name: create-task-summary
description: 直近一週間で自身が作成したPRを取得し、やったことのサマリーを作成する。週次報告や作業振り返り時に使用。
disable-model-invocation: true
allowed-tools: Bash(gh:*)
---

# Create Task Summary

直近一週間で自身が作成したPRを取得し、やったことのサマリーを作成するスキル。

## 実行手順

### 1. 現在のGitHubユーザー名を取得

```bash
gh api user --jq '.login'
```

### 2. 直近一週間のPRを取得

```bash
gh pr list --author "@me" --state all --search "created:>=$(date -v-7d +%Y-%m-%d)" --json number,title,url,body,mergedAt,state --limit 100
```

### 3. 出力フォーマット

取得したPRの内容をもとに、以下の形式で出力する:

```markdown
## 直近一週間の作業サマリー

### [カテゴリ/機能名]
- やったことの概要を簡潔に記載
- 関連PR:
  - [PR Title](PR URL)
  - [PR Title](PR URL)

### [カテゴリ/機能名]
- やったことの概要を簡潔に記載
- 関連PR:
  - [PR Title](PR URL)
```

## 注意事項

- PRのタイトルとbodyから作業内容を判断し、関連するPRをグルーピングする
- 同じ機能や目的に関連するPRはまとめて記載する
- マージ済み・オープン・クローズドすべてのPRを対象とする
