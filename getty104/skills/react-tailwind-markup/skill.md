---
name: react-tailwind-markup
description: React + Tailwind CSSを使用したマークアップを実装します。Flexboxベースのレイアウト、globals.cssのカラー定義の使用、TDD開発に対応し、コンポーネントの視覚的検証をサポートします。
---

# React + Tailwind CSS Markup Implementation

## 概要

このSkillは、React + Tailwind CSSを使用した高品質なマークアップの実装をガイドします。
デザインの一貫性、保守性、アクセシビリティを重視した開発を実現します。

## 基本原則

### 1. Tailwind CSSの使用

- **全てのスタイリングはTailwind CSSで実装**
- インラインスタイルやCSSファイルは使用しない
- カスタムCSSクラスの定義は避ける

### 2. Flexboxベースのレイアウト

#### 横並び配置
```tsx
<div className="flex gap-4">
  <div>要素1</div>
  <div>要素2</div>
  <div>要素3</div>
</div>
```

- `flex`: フレックスコンテナを作成
- `gap-{size}`: 要素間のスペースを定義（gap-2, gap-4, gap-6など）
- 方向制御: `flex-row`（デフォルト）
- 配置: `justify-start`, `justify-center`, `justify-end`, `justify-between`, `justify-around`

#### 縦並び配置
```tsx
<div className="flex flex-col gap-4">
  <div>要素1</div>
  <div>要素2</div>
  <div>要素3</div>
</div>
```

- `flex-col`: 縦方向のフレックスコンテナ
- `gap-{size}`: 要素間の縦方向スペース
- 配置: `items-start`, `items-center`, `items-end`, `items-stretch`

### 3. Margin/Paddingの使用制限

#### 許可される使用ケース

**要素内のパディング（コンテンツの内側余白）:**
```tsx
<div className="p-4">
  <h1>タイトル</h1>
  <p>本文</p>
</div>
```

**左右寄せ:**
```tsx
<div className="ml-auto">右寄せされる要素</div>
<div className="mr-auto">左寄せされる要素</div>
<div className="mx-auto">中央寄せされる要素</div>
```

**上下寄せ:**
```tsx
<div className="mt-auto">下寄せされる要素</div>
<div className="mb-auto">上寄せされる要素</div>
<div className="my-auto">中央寄せされる要素</div>
```

#### 避けるべき使用ケース

**要素間のスペースにmarginを使用:**
```tsx
❌ <div className="mb-4">要素1</div>
❌ <div className="mb-4">要素2</div>

✅ <div className="flex flex-col gap-4">
     <div>要素1</div>
     <div>要素2</div>
   </div>
```

### 4. カラー定義の使用

#### globals.cssの確認

プロジェクトの`globals.css`（または`app/globals.css`、`src/globals.css`など）を確認し、定義済みのカラー変数を使用します。

```css
/* globals.css の例 */
:root {
  --primary: 210 100% 50%;
  --secondary: 280 80% 60%;
  --background: 0 0% 100%;
  --foreground: 0 0% 0%;
  --muted: 210 10% 95%;
  --accent: 180 100% 45%;
}
```

#### Tailwindでのカラー使用

```tsx
<div className="bg-primary text-primary-foreground">
  プライマリカラー
</div>

<div className="bg-secondary text-secondary-foreground">
  セカンダリカラー
</div>

<div className="bg-muted text-muted-foreground">
  ミュートカラー
</div>
```

#### カスタムカラーの禁止

```tsx
❌ <div className="bg-[#FF5733]">カスタムカラー</div>
❌ <div className="text-[rgb(255,87,51)]">カスタムカラー</div>

✅ <div className="bg-primary">定義済みカラー</div>
```

## 実装ワークフロー

### ステップ1: globals.cssの確認

マークアップを開始する前に、プロジェクトのカラー定義を確認します。

```bash
# globals.cssの検索
find . -name "globals.css" -o -name "global.css" | grep -v node_modules
```

Serenaを使用してカラー定義を確認
```
mcp__plugin_getty104_serena__search_for_pattern を使用して、
":root" パターンで globals.css を検索
```

### ステップ2: コンポーネント設計

#### レイアウト構造の決定

1. **コンテナの階層を設計**
   - 最上位: ページまたはセクションのコンテナ
   - 中層: グリッドまたはフレックスコンテナ
   - 最下層: 個別のコンポーネント

2. **フレックスの方向を決定**
   - 横並び → `flex`
   - 縦並び → `flex-col`
   - レスポンシブ → `flex-col md:flex-row`

3. **スペーシングを定義**
   - 要素間 → `gap-{size}`
   - 内側余白 → `p-{size}`, `px-{size}`, `py-{size}`
   - 外側余白 → 寄せの目的でのみ使用

#### コンポーネント例

```tsx
// カード型コンポーネント
export function Card({ title, description, actions }) {
  return (
    <div className="flex flex-col gap-4 p-6 bg-card text-card-foreground rounded-lg shadow-md">
      <h2 className="text-2xl font-bold">{title}</h2>
      <p className="text-muted-foreground">{description}</p>
      <div className="flex gap-2 mt-auto">
        {actions}
      </div>
    </div>
  );
}

// リスト型コンポーネント
export function List({ items }) {
  return (
    <div className="flex flex-col gap-2">
      {items.map((item, index) => (
        <div key={index} className="flex items-center gap-3 p-3 bg-muted rounded">
          <div className="flex-shrink-0">
            {item.icon}
          </div>
          <div className="flex-1">{item.text}</div>
          {item.action && (
            <div className="ml-auto">{item.action}</div>
          )}
        </div>
      ))}
    </div>
  );
}

// グリッドレイアウト
export function Grid({ children }) {
  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
      {children}
    </div>
  );
}
```

### ステップ3: TDDアプローチでの実装

#### 3.1 テストの作成

マークアップのテストは以下の観点で作成：

1. **スナップショットテスト**: レンダリング結果の変化検知
2. **アクセシビリティテスト**: ARIAラベル、セマンティックHTML
3. **視覚的回帰テスト**: StorybookやPlaywrightでの検証

```tsx
// Component.test.tsx
import { render, screen } from '@testing-library/react';
import { Card } from './Card';

describe('Card', () => {
  it('should render title and description', () => {
    render(
      <Card
        title="Test Title"
        description="Test Description"
        actions={<button>Action</button>}
      />
    );

    expect(screen.getByText('Test Title')).toBeInTheDocument();
    expect(screen.getByText('Test Description')).toBeInTheDocument();
  });

  it('should match snapshot', () => {
    const { container } = render(
      <Card
        title="Test Title"
        description="Test Description"
        actions={<button>Action</button>}
      />
    );

    expect(container.firstChild).toMatchSnapshot();
  });
});
```

#### 3.2 テストの実行（失敗確認）

```bash
npm test -- Card.test.tsx
```

#### 3.3 コンポーネントの実装

テストが通るようにコンポーネントを実装します。

#### 3.4 視覚的検証（オプション）

Storybookが利用可能な場合：

```tsx
// Card.stories.tsx
import type { Meta, StoryObj } from '@storybook/react';
import { Card } from './Card';

const meta: Meta<typeof Card> = {
  title: 'Components/Card',
  component: Card,
};

export default meta;
type Story = StoryObj<typeof Card>;

export const Default: Story = {
  args: {
    title: 'Card Title',
    description: 'This is a card description',
    actions: <button className="px-4 py-2 bg-primary text-primary-foreground rounded">Action</button>,
  },
};
```

### ステップ4: レスポンシブデザイン

Tailwindのブレークポイントを使用：

```tsx
<div className="flex flex-col gap-4 md:flex-row md:gap-6 lg:gap-8">
  <div className="w-full md:w-1/2 lg:w-1/3">要素1</div>
  <div className="w-full md:w-1/2 lg:w-2/3">要素2</div>
</div>
```

ブレークポイント:
- `sm`: 640px
- `md`: 768px
- `lg`: 1024px
- `xl`: 1280px
- `2xl`: 1536px

### ステップ5: アクセシビリティの確保

```tsx
<button
  className="px-4 py-2 bg-primary text-primary-foreground rounded"
  aria-label="メニューを開く"
>
  <MenuIcon />
</button>

<nav aria-label="メインナビゲーション">
  <ul className="flex gap-4">
    <li><a href="/">ホーム</a></li>
    <li><a href="/about">概要</a></li>
  </ul>
</nav>
```

### ステップ6: 品質チェック

実装完了後、以下を実行：

```bash
# テストの実行
npm test

# Lintの実行
npm run lint

# 型チェック
npm run type-check
```

## ベストプラクティス

### 1. クラス名の整理

条件付きクラスには`clsx`または`cn`ユーティリティを使用：

```tsx
import { cn } from '@/lib/utils';

<div className={cn(
  "flex gap-4",
  isActive && "bg-primary",
  isDisabled && "opacity-50"
)}>
  {children}
</div>
```

### 2. 再利用可能なコンポーネント

共通のレイアウトパターンをコンポーネント化：

```tsx
// Stack.tsx
interface StackProps {
  direction?: 'horizontal' | 'vertical';
  gap?: number;
  children: React.ReactNode;
  className?: string;
}

export function Stack({
  direction = 'vertical',
  gap = 4,
  children,
  className
}: StackProps) {
  return (
    <div className={cn(
      "flex",
      direction === 'vertical' ? "flex-col" : "flex-row",
      `gap-${gap}`,
      className
    )}>
      {children}
    </div>
  );
}
```

### 3. セマンティックHTML

適切なHTML要素を使用：

```tsx
✅ <button>クリック</button>
❌ <div onClick={...}>クリック</div>

✅ <nav><ul><li><a href="/">ホーム</a></li></ul></nav>
❌ <div><div><div><span onClick={...}>ホーム</span></div></div></div>
```

## トラブルシューティング

### gap が効かない場合

- 親要素に`flex`または`flex-col`が設定されているか確認
- 子要素に`absolute`などのポジショニングが設定されていないか確認

### カラーが反映されない場合

- `globals.css`でカラー変数が定義されているか確認
- Tailwind設定ファイル（`tailwind.config.js`）でカラーが拡張されているか確認

### レスポンシブが機能しない場合

- ブレークポイントのプレフィックスが正しいか確認（`md:`、`lg:`など）
- ビューポートメタタグが設定されているか確認

## チェックリスト

実装完了前に以下を確認：

- [ ] 全てのスタイリングがTailwind CSSで実装されている
- [ ] 要素間のスペーシングは`gap`を使用している
- [ ] `margin`/`padding`は適切な用途でのみ使用されている
- [ ] カラーは`globals.css`の定義から選択されている
- [ ] レスポンシブデザインが考慮されている
- [ ] セマンティックHTMLが使用されている
- [ ] アクセシビリティ属性が設定されている
- [ ] テストが通過している
- [ ] Lintエラーがない
- [ ] 型エラーがない
- [ ] コード内にコメントが残っていない

## まとめ

このSkillに従うことで、以下を実現できます：

- 一貫性のあるデザイン実装
- 保守性の高いコンポーネント
- アクセシブルなUI
- レスポンシブ対応
- TDDによる品質保証

マークアップ実装の際は、このガイドラインを常に参照し、ベストプラクティスに従ってください。
