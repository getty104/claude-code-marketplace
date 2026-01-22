# Check Library - Examples

このドキュメントでは、check-libraryスキルの具体的な使用例を示します。

## 例1: Next.jsのApp Routerについて調べる

### シナリオ

Next.js App Routerのレイアウト機能を使ってネストされたレイアウトを実装したい

### 手順

```bash
# 1. Next.js DevTools MCPの初期化
mcp__plugin_getty104_next-devtools__init

# 2. App Routerのレイアウト機能について検索
mcp__plugin_getty104_next-devtools__nextjs_docs
  action: "search"
  query: "nested layouts app router"

# 3. 詳細なドキュメントを取得（検索結果からパスを特定）
mcp__plugin_getty104_next-devtools__nextjs_docs
  action: "get"
  path: "app/building-your-application/routing/layouts-and-templates"
```

### 期待される結果

1. Next.jsの最新公式ドキュメントからレイアウト機能の情報を取得
2. ネストされたレイアウトの実装方法を理解
3. コード例と使用パターンを確認

## 例2: Next.jsのServer Actionsを実装

### シナリオ

フォーム送信にServer Actionsを使用したい

### 手順

```bash
# Next.js DevTools MCPでServer Actionsのドキュメントを検索
mcp__plugin_getty104_next-devtools__nextjs_docs
  action: "search"
  query: "server actions forms"
```

### 期待される結果

1. Server Actionsの基本的な使用方法を取得
2. フォームとの統合方法を理解
3. エラーハンドリングとバリデーションのパターンを確認

## 例3: shadcn/uiのButtonコンポーネントを追加

### シナリオ

プロジェクトにshadcn/uiのButtonコンポーネントを追加したい

### 手順

```bash
# shadcn MCPのツールを確認
ListMcpResourcesTool
  server: "shadcn"

# Buttonコンポーネントの情報を取得
# (利用可能なツールに応じて適切なツールを使用)
```

### 期待される結果

1. Buttonコンポーネントのインストール方法を取得
2. コンポーネントのバリエーションと使用方法を理解
3. カスタマイズオプションを確認

## 例4: shadcn/uiのFormコンポーネントとReact Hook Formの統合

### シナリオ

shadcn/uiのFormコンポーネントとReact Hook Formを組み合わせて、フォームバリデーションを実装したい

### 手順

```bash
# shadcn MCPでFormコンポーネントの情報を取得
# (shadcn側のツールを使用)

# Context7 MCPでReact Hook Formのドキュメントを取得
mcp__plugin_getty104_context7__resolve-library-id
  libraryName: "react-hook-form"

mcp__plugin_getty104_context7__get-library-docs
  context7CompatibleLibraryID: "/react-hook-form/react-hook-form"
  topic: "integration validation"
  page: 1
```

### 期待される結果

1. shadcn/uiのFormコンポーネントの使用方法を理解
2. React Hook Formとの統合パターンを確認
3. バリデーションの実装方法を取得

## 例5: React Queryでデータフェッチングを実装

### シナリオ

React Query (TanStack Query) を使用してAPIからデータを取得したい

### 手順

```bash
# 1. ライブラリIDを解決
mcp__plugin_getty104_context7__resolve-library-id
  libraryName: "tanstack query"

# 2. useQueryフックのドキュメントを取得
mcp__plugin_getty104_context7__get-library-docs
  context7CompatibleLibraryID: "/tanstack/query"
  topic: "useQuery"
  page: 1

# 3. キャッシュ管理について追加で調べる
mcp__plugin_getty104_context7__get-library-docs
  context7CompatibleLibraryID: "/tanstack/query"
  topic: "cache invalidation"
  page: 1
```

### 期待される結果

1. React Queryの最新バージョンのドキュメントを取得
2. useQueryフックの使用方法を理解
3. キャッシュ管理のベストプラクティスを確認

## 例6: Zodでスキーマバリデーションを実装

### シナリオ

Zodを使用してフォームデータのバリデーションスキーマを定義したい

### 手順

```bash
# 1. ライブラリIDを解決
mcp__plugin_getty104_context7__resolve-library-id
  libraryName: "zod"

# 2. スキーマ定義のドキュメントを取得
mcp__plugin_getty104_context7__get-library-docs
  context7CompatibleLibraryID: "/colinhacks/zod"
  topic: "schema validation"
  page: 1
```

### 期待される結果

1. Zodの基本的なスキーマ定義方法を取得
2. バリデーションルールの記述方法を理解
3. TypeScript型推論の活用方法を確認

## 例7: Tailwind CSSのカスタム設定

### シナリオ

Tailwind CSSでカスタムカラーとブレークポイントを設定したい

### 手順

```bash
# 1. ライブラリIDを解決
mcp__plugin_getty104_context7__resolve-library-id
  libraryName: "tailwindcss"

# 2. 設定方法のドキュメントを取得
mcp__plugin_getty104_context7__get-library-docs
  context7CompatibleLibraryID: "/tailwindlabs/tailwindcss"
  topic: "configuration customization"
  page: 1
```

### 期待される結果

1. tailwind.config.jsの設定方法を取得
2. カスタムカラーの定義方法を理解
3. レスポンシブブレークポイントのカスタマイズ方法を確認

## 例8: Prismaでデータベーススキーマを定義

### シナリオ

Prismaを使用してリレーショナルデータベースのスキーマを定義したい

### 手順

```bash
# 1. ライブラリIDを解決
mcp__plugin_getty104_context7__resolve-library-id
  libraryName: "prisma"

# 2. スキーマ定義のドキュメントを取得
mcp__plugin_getty104_context7__get-library-docs
  context7CompatibleLibraryID: "/prisma/prisma"
  topic: "schema relations"
  page: 1

# 3. マイグレーションについて追加で調べる
mcp__plugin_getty104_context7__get-library-docs
  context7CompatibleLibraryID: "/prisma/prisma"
  topic: "migrations"
  page: 1
```

### 期待される結果

1. Prismaスキーマの基本的な記述方法を取得
2. リレーションの定義方法を理解
3. マイグレーション管理のベストプラクティスを確認

## 例9: 複数ライブラリを組み合わせた実装

### シナリオ

Next.js App Router + React Hook Form + Zod + Server Actionsでフォームを実装したい

### 手順

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

### 期待される結果

1. 各ライブラリの最新ドキュメントを取得
2. ライブラリ間の統合パターンを理解
3. ベストプラクティスに基づいた実装方法を確認

## ライブラリ選択のポイント

### 1. Next.js関連の判定基準

以下のキーワードが含まれる場合は、Next.js DevTools MCPを使用：
- Next.js、App Router、Pages Router
- Server Components、Server Actions
- Route Handlers、Middleware
- next/image、next/link、next/font
- generateStaticParams、generateMetadata

### 2. shadcn/ui関連の判定基準

以下のキーワードが含まれる場合は、shadcn MCPを使用：
- shadcn/ui、shadcn
- Radix UI（shadcnのベース）
- Button、Card、Dialog、Form などのshadcnコンポーネント名

### 3. Context7使用の判定基準

上記以外の一般的なライブラリ：
- React Query (TanStack Query)
- Zod、Yup などのバリデーションライブラリ
- Tailwind CSS
- Prisma、Drizzle などのORM
- Axios、SWR などのデータフェッチングライブラリ
- その他のnpmパッケージ

## 効果的な使用方法

### トピック指定のコツ

Context7でドキュメントを取得する際は、具体的なトピックを指定すると効果的：

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

情報が不足している場合は、pageパラメータを変更して追加情報を取得：

```bash
# 1ページ目で基本情報を取得
mcp__plugin_getty104_context7__get-library-docs
  context7CompatibleLibraryID: "/prisma/prisma"
  topic: "schema"
  page: 1

# 2ページ目で詳細情報を取得
mcp__plugin_getty104_context7__get-library-docs
  context7CompatibleLibraryID: "/prisma/prisma"
  topic: "schema"
  page: 2
```

### ライブラリ名解決のコツ

`resolve-library-id`では、正式なライブラリ名だけでなく、一般的な呼び方でも検索可能：

```bash
# どちらでも動作
mcp__plugin_getty104_context7__resolve-library-id
  libraryName: "react-hook-form"

mcp__plugin_getty104_context7__resolve-library-id
  libraryName: "react hook form"

mcp__plugin_getty104_context7__resolve-library-id
  libraryName: "rhf"
```

## まとめ

check-libraryスキルを効果的に使用するためのポイント：

1. **ライブラリの種類を正しく判定**: Next.js、shadcn、その他を適切に区別
2. **具体的なトピックを指定**: 必要な情報を効率的に取得
3. **複数のMCPを組み合わせる**: 統合パターンを理解するために複数のライブラリを調査
4. **最新情報を確認**: 各MCPは最新のドキュメントを提供
5. **段階的に深掘り**: まず概要を取得し、必要に応じて詳細を調査

これらの原則に従うことで、ライブラリの正しい使用方法を迅速に理解し、品質の高い実装が可能になります。
