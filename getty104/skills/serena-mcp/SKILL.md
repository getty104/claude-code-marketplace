---
name: serena-mcp
description: Serenaエキスパート - コード編集・解析作業時に最優先で使用。プロジェクト初期化、シンボル検索、効率的なコード変更を支援。
---

# Serena MCP エキスパートガイド

## 使用タイミング

- **プロジェクト開始時（必須）**: `.serena`ディレクトリが存在しない場合
- **コード編集・解析時（最優先）**: ファイル全体読込の代わりにシンボル単位で操作
- **リファクタリング時**: 依存関係を分析してから変更

## 重要な原則

1. **ファイル全体読込は最終手段**: まずSerenaでシンボル検索
2. **トークン効率**: シンボル単位の操作で大幅削減
3. **変更前の確認**: `think_about_task_adherence()`を必ず呼び出す
4. **正規表現活用**: `replace_content`は正規表現モードでワイルドカードを使用
5. **Worktree使用時**: `.serena`を親からコピー（`cp -r ../.serena .serena`）

## 必須手順

### 1. プロジェクト初期化（初回のみ）

```
ls -la .serena

# 存在しない場合
mcp__serena__activate_project(project=".")
mcp__serena__check_onboarding_performed()
mcp__serena__onboarding()  # 未実施の場合
```

### 2. コード分析ワークフロー

#### シンボル概要取得
```
mcp__serena__get_symbols_overview(
  relative_path="src/file.ts",
  depth=0  # 0=トップレベルのみ, 1=直接の子も含む
)
```

#### シンボル検索
```
# 名前パスパターンで検索
mcp__serena__find_symbol(
  name_path_pattern="ClassName/methodName",  # 相対パス
  name_path_pattern="/ClassName/methodName", # 絶対パス（完全一致）
  name_path_pattern="methodName",            # 単純名
  relative_path="src/",                      # 検索範囲を制限
  include_body=True,                         # ソースコードを含む
  depth=1,                                   # 子要素も取得
  substring_matching=True                    # 部分一致検索
)
```

#### 依存関係分析
```
mcp__serena__find_referencing_symbols(
  name_path="functionName",
  relative_path="src/file.ts"  # ファイル指定必須
)
```

#### パターン検索
```
mcp__serena__search_for_pattern(
  substring_pattern="TODO|FIXME",           # 正規表現
  relative_path="src/",                     # 検索範囲
  paths_include_glob="*.ts",                # 含むファイル
  paths_exclude_glob="*test*",              # 除外ファイル
  restrict_search_to_code_files=True,       # コードファイルのみ
  context_lines_before=2,                   # 前後の行数
  context_lines_after=2
)
```

### 3. コード編集

#### シンボル置換（推奨）
```
mcp__serena__replace_symbol_body(
  name_path="methodName",
  relative_path="src/file.ts",
  body="function methodName() { ... }"  # シグネチャ含む、docstring/import除く
)
```

#### コンテンツ置換（柔軟）
```
mcp__serena__replace_content(
  relative_path="src/file.ts",
  needle="beginning.*?end",  # 正規表現推奨
  repl="新しいコンテンツ",
  mode="regex",              # "literal" or "regex"
  allow_multiple_occurrences=False
)
```

#### シンボル前後に挿入
```
# import文追加など
mcp__serena__insert_before_symbol(
  name_path="firstSymbol",
  relative_path="src/file.ts",
  body="import { X } from 'y';\n"
)

# 新規メソッド追加など
mcp__serena__insert_after_symbol(
  name_path="lastMethod",
  relative_path="src/file.ts",
  body="\n  newMethod() { ... }"
)
```

#### シンボルリネーム
```
mcp__serena__rename_symbol(
  name_path="oldName",
  relative_path="src/file.ts",
  new_name="newName"  # コードベース全体で変更
)
```

### 4. ファイル操作

```
# ディレクトリ一覧
mcp__serena__list_dir(relative_path="src/", recursive=True)

# ファイル検索
mcp__serena__find_file(file_mask="*.test.ts", relative_path="src/")

# ファイル読込（シンボル操作が不可能な場合のみ）
mcp__serena__read_file(
  relative_path="config.json",
  start_line=0,
  end_line=50
)

# ファイル作成/上書き
mcp__serena__create_text_file(
  relative_path="src/new-file.ts",
  content="// 内容"
)
```

### 5. プロジェクト知識管理（メモリ）

```
# メモリ一覧
mcp__serena__list_memories()

# メモリ読込
mcp__serena__read_memory(memory_file_name="architecture.md")

# メモリ保存
mcp__serena__write_memory(
  memory_file_name="decisions.md",
  content="# 設計決定\n..."
)

# メモリ編集
mcp__serena__edit_memory(
  memory_file_name="decisions.md",
  needle="old text",
  repl="new text",
  mode="literal"  # or "regex"
)

# メモリ削除
mcp__serena__delete_memory(memory_file_name="outdated.md")
```

### 6. 思考・確認ツール

```
# 情報収集後に呼び出し
mcp__serena__think_about_collected_information()

# コード変更前に呼び出し（必須）
mcp__serena__think_about_task_adherence()

# タスク完了時に呼び出し
mcp__serena__think_about_whether_you_are_done()
```

### 7. その他

```
# シェルコマンド実行
mcp__serena__execute_shell_command(
  command="npm run build",
  cwd=None  # Noneでプロジェクトルート
)

# 現在の設定確認
mcp__serena__get_current_config()

# モード切替
mcp__serena__switch_modes(modes=["editing", "interactive"])
```

## LSPシンボル種別（include_kinds/exclude_kinds用）

| 値 | 種別 | 値 | 種別 |
|---|---|---|---|
| 1 | file | 14 | constant |
| 2 | module | 15 | string |
| 3 | namespace | 16 | number |
| 4 | package | 17 | boolean |
| 5 | class | 18 | array |
| 6 | method | 19 | object |
| 7 | property | 20 | key |
| 8 | field | 21 | null |
| 9 | constructor | 22 | enum member |
| 10 | enum | 23 | struct |
| 11 | interface | 24 | event |
| 12 | function | 25 | operator |
| 13 | variable | 26 | type parameter |

## 参照

- 公式ドキュメント: https://oraios.github.io/serena/_sources/02-usage/050_configuration.md
