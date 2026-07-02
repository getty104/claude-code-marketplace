# Check Library - Examples

check-libraryスキルの具体的な使用例。

## 例1: Next.js関連（App Router / Server Actionsなど）

Next.jsのレイアウト機能やServer Actionsなどを調べるケース。

```bash
# 1. Next.js DevTools MCPの初期化
mcp__plugin_getty104_next-devtools__init

# 2. キーワードで検索
mcp__plugin_getty104_next-devtools__nextjs_docs
  action: "search"
  query: "nested layouts app router"

# 3. 詳細なドキュメントを取得（検索結果からパスを特定）
mcp__plugin_getty104_next-devtools__nextjs_docs
  action: "get"
  path: "app/building-your-application/routing/layouts-and-templates"
```

他のNext.jsトピックも同様に `action: "search"` の `query` を変えて検索する（例: `"server actions forms"`）。

## 例2: shadcn/uiのコンポーネントを追加

shadcn/uiのButtonコンポーネントなどをプロジェクトに追加するケース。

```bash
# shadcn MCPのツールを確認
ListMcpResourcesTool
  server: "shadcn"

# Buttonコンポーネントの情報を取得
# (利用可能なツールに応じて適切なツールを使用)
```

インストール方法・バリエーション・カスタマイズオプションを取得できる。

## 例3: 一般ライブラリ（context7）

React Query (TanStack Query) の例。Zod / Tailwind CSS / Prisma / React Hook Form など他の一般ライブラリも同じ流れ（`resolve-library-id` → `get-library-docs`）で調べる。

```bash
# 1. ライブラリIDを解決
mcp__plugin_getty104_context7__resolve-library-id
  libraryName: "tanstack query"

# 2. トピックを指定してドキュメントを取得
mcp__plugin_getty104_context7__get-library-docs
  context7CompatibleLibraryID: "/tanstack/query"
  topic: "useQuery"
  page: 1

# 3. 追加で調べたい場合はtopicを変えて再取得
mcp__plugin_getty104_context7__get-library-docs
  context7CompatibleLibraryID: "/tanstack/query"
  topic: "cache invalidation"
  page: 1
```

## 例4: 複数ライブラリを組み合わせた実装

Next.js App Router + React Hook Form + Zod + Server Actionsでフォームを実装するケース。各ライブラリを担当するMCPを順に使い、統合パターンを調べる。

```bash
# 1. Next.js Server Actionsのドキュメントを確認
mcp__plugin_getty104_next-devtools__nextjs_docs
  action: "search"
  query: "server actions form validation"

# 2. React Hook Formの統合方法を確認
mcp__plugin_getty104_context7__resolve-library-id
  libraryName: "react-hook-form"

mcp__plugin_getty104_context7__get-library-docs
  context7CompatibleLibraryID: "/react-hook-form/react-hook-form"
  topic: "server actions"
  page: 1

# 3. Zodのスキーマ定義を確認
mcp__plugin_getty104_context7__resolve-library-id
  libraryName: "zod"

mcp__plugin_getty104_context7__get-library-docs
  context7CompatibleLibraryID: "/colinhacks/zod"
  topic: "integration react-hook-form"
  page: 1
```

shadcn/uiコンポーネントと一般ライブラリの組み合わせ（例: shadcnのForm + React Hook Form）も同様に、shadcn MCPとcontext7を併用する。

## ライブラリ選択のポイント

### 1. Next.js関連の判定基準（Next.js DevTools MCPを使用）

以下のキーワードが含まれる場合:
- Next.js、App Router、Pages Router
- Server Components、Server Actions
- Route Handlers、Middleware
- next/image、next/link、next/font
- generateStaticParams、generateMetadata

### 2. shadcn/ui関連の判定基準（shadcn MCPを使用）

以下のキーワードが含まれる場合:
- shadcn/ui、shadcn
- Radix UI（shadcnのベース）
- Button、Card、Dialog、Form などのshadcnコンポーネント名

### 3. Context7使用の判定基準（上記以外の一般的なライブラリ）

- React Query (TanStack Query)
- Zod、Yup などのバリデーションライブラリ
- Tailwind CSS
- Prisma、Drizzle などのORM
- Axios、SWR などのデータフェッチングライブラリ
- その他のnpmパッケージ

## 効果的な使用方法

### トピック指定のコツ

Context7でドキュメントを取得する際は、具体的なトピックを指定すると効果的:

```bash
# 悪い例：トピック指定なし
mcp__plugin_getty104_context7__get-library-docs
  context7CompatibleLibraryID: "/tanstack/query"

# 良い例：具体的なトピックを指定
mcp__plugin_getty104_context7__get-library-docs
  context7CompatibleLibraryID: "/tanstack/query"
  topic: "useQuery mutations error handling"
  page: 1
```

### ページネーション活用

情報が不足している場合は、`page`パラメータを増やして追加情報を取得する（`page: 1`で基本情報 → `page: 2`で詳細情報）。

### ライブラリ名解決のコツ

`resolve-library-id`は正式なライブラリ名だけでなく、一般的な呼び方でも検索可能（例: `"react-hook-form"` / `"react hook form"` / `"rhf"` のいずれでも動作）。

## まとめ

1. **ライブラリの種類を正しく判定**: Next.js、shadcn、その他を適切に区別
2. **具体的なトピックを指定**: 必要な情報を効率的に取得
3. **複数のMCPを組み合わせる**: 統合パターンを理解するために複数のライブラリを調査
4. **最新情報を確認**: 各MCPは最新のドキュメントを提供
5. **段階的に深掘り**: まず概要を取得し、必要に応じて詳細を調査
