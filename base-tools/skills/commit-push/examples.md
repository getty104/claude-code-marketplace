# High Quality Commit - Examples

実際の開発シナリオでの具体的な使用例。

## 例1: 初回実装でのgitコミット（新規コミット）

新機能を実装し、ブランチで初めてgit commitするケース。

```bash
# 1. ブランチ状況確認
git status
git log --oneline --graph "origin/$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)..HEAD"
# (no commits yet on this branch)

# 2. 戦略判断: ブランチに初めてのgitコミット → 新規gitコミット
git add -A
git commit
```

gitコミットメッセージ例:

```
feat: add user profile editing feature

Implement profile editing functionality:
- Add ProfileEditForm component with validation
- Add PUT /api/users/:id endpoint
- Integrate form with existing UserProfile component

Users can now update their display name, email, and bio.

Closes #234
```

バグ修正の場合も同様に、`fix:` タイプで「何を直したか・なぜ必要か・テスト追加」をbodyに記述する（例: `fix: correct email validation regex`）。

## 例2: レビュー指摘への対応（Squash）

PR作成後、レビュー指摘（例: バリデーションロジックの改善）を受けて修正するケース。

```bash
# 1. 現在のコミット確認
git log --oneline --graph "origin/$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)..HEAD"
# * a1b2c3d feat: add user profile editing feature

# 2. 指摘箇所を修正...

# 3. 戦略判断: 既存コミットと同じテーマ → Squash
git add -A
git commit --amend
# メッセージに改善内容（例: Validation improvements の詳細）を追記

# 4. 強制push（PRを更新）
git push --force-with-lease
```

## 例3: 独立した機能追加（新規コミット）

既存コミット（プロフィール編集）とは別の機能（画像アップロード）を追加するケース。

```bash
# 1. 現在のコミット確認
git log --oneline --graph "origin/$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)..HEAD"
# * a1b2c3d feat: add user profile editing feature

# 2. 機能を実装...

# 3. 戦略判断: 既存コミットとは独立した機能 → 新規コミット
git add -A
git commit

# 4. 結果確認
git log --oneline --graph "origin/$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)..HEAD"
# * e4f5g6h feat: add profile picture upload
# * a1b2c3d feat: add user profile editing feature
```

## 例4: WIPコミットの整理（Interactive Rebase）

開発中に多数の小さなコミットを作成してしまい、PR作成前に整理するケース。

```bash
git log --oneline --graph "origin/$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)..HEAD"
# * h7i8j9k WIP: fix typo
# * e4f5g6h WIP: add validation
# * b2c3d4e feat: add profile form
# * y9z0a1b WIP: experiment with layout
# * v6w7x8y feat: add user model
# * s3t4u5v fix: import statement

# Interactive rebaseを開始（エディタが開く）
git rebase -i "origin/$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)"
```

エディタでの編集:

```
pick v6w7x8y feat: add user model
squash s3t4u5v fix: import statement
drop y9z0a1b WIP: experiment with layout
pick b2c3d4e feat: add profile form
squash e4f5g6h WIP: add validation
squash h7i8j9k WIP: fix typo
```

保存後、統合された各コミットのメッセージを意味のある内容（何を実装したか・なぜ）に書き直す。結果、クリーンな2コミットに整理される:

```bash
git log --oneline --graph "origin/$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)..HEAD"
# * m1n2o3p feat: add profile editing form
# * j4k5l6m feat: add user profile model
```

## 例5: 複数機能の段階的実装（段階ごとに新規コミット）

大きな機能（例: 認証システム）を Model → API → UI の順で段階的に実装するケース。段階ごとに対象ファイルをステージングしてコミット・pushする。

```bash
# ステップ1: モデル実装
git add src/models/
git commit -m "feat: add authentication model"
git push

# ステップ2: API実装
git add src/api/auth.ts
git commit -m "feat: add authentication API endpoints"
git push

# ステップ3: UI実装
git add src/components/auth/
git commit -m "feat: add authentication UI components"
git push
```

各コミットメッセージには例1と同様にbody（実装内容の箇条書きと理由）を含める。各コミットが独立してレビュー・ビルド・テスト可能になる。

## まとめ

1. **適切な戦略選択**: シナリオに応じてSquash/新規gitコミット/Rebaseを使い分け
2. **明確なメッセージ**: 「なぜ」その変更が必要だったのかを記述
3. **論理的な単位**: 各gitコミットが独立して理解できる粒度
4. **継続的な改善**: レビューフィードバックを反映して品質向上
