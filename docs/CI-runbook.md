# CI Runbook — PR #32 と最近の修正のまとめ

更新日: 2026-10-13
リポジトリ: FuJiK/myblog
関連PR: https://github.com/FuJiK/myblog/pull/32

## 1) 適用した変更（このリポジトリに反映済）
- stylelint の設定修正
  - ファイル: `stylelint.config.js`
  - 内容: Tailwind の at-rule（`@apply`, `@layer`, `@screen`, `@tailwind` 等）を許可するために `at-rule-no-unknown` ルールの ignoreAtRules を追加。
  - コミット: `Fix stylelint config for Tailwind at-rules used by Nuxt project`

- PR #32 のマージ（`fix/nuxt-generate-force-build` → `main`）
  - 目的: CI 上で必ず static site をビルドするために `nuxt generate --force-build` などの変更を含む。
  - マージ後のコミット: `Merge pull request #32 from FuJiK/fix/nuxt-generate-force-build`（main に反映済）

## 2) どの変更が本当に通ったか（実行結果の要約）
- stylelint 設定修正の push 実行（単独コミット）:
  - CodeQL: 成功
  - cd workflow: 失敗（当該実行での別問題が原因）
  - その後の再試行で main 上の該当ワークフローは成功傾向に戻っています。

- PR #32 をマージした際に自動実行されたワークフロー（主要な実行結果）:
  - PR Gate（.github/workflows/pr-gate.yml）: 失敗（PR 時点の lint エラー等で失敗していた実行が確認されていましたが、stylelint 修正が適用された別のコミット後は改善）
  - cd (.github/workflows/cd.yml): 成功（run id: 38384251121）
  - pages build and deployment: 成功（run id: 38384358223）
  - CodeQL: 成功

→ 総合判断: stylelint の root cause は修正済み。main ブランチ上で CI/CD（generate・pages deploy 等）は成功している状態です。

## 3) さらに残る CI の確認ポイント（短期）
- 現状ウォッチする項目:
  1. Lint (ESLint) — `npm run lint:js`
     - eslint のルールによる新しいエラーが PR に紛れ込んでいないか確認
     - コマンド: `npm run lint:js`
  2. Style lint — `npm run lint:style`
     - 今回の設定で Tailwind の at-rule は無視されるようになりましたが、別の stylelint ルール違反（プロパティ順など）が出る可能性あり
     - コマンド: `npx stylelint "{assets,components,layouts,pages,plugins}/**/*.{vue,css}" --ignore-path .gitignore`
  3. Generate / sitemap — `npm run generate` と `scripts/generate-sitemap.js`
     - `dist/` が期待どおりに出来るか、sitemap が生成されるか
     - ローカル: `npm run generate`
  4. Site Regression workflow
     - サイトの回帰テスト（.github/workflows/site-regression.yml）が失敗していないか
  5. Dependency Review
     - リポジトリの dependency-graph が有効（GitHub 側）であるか、Dependency Review が意図どおり skip/実行されているか

- 定期確認の方法:
  - GitHub Actions タブで main の最新実行ログを確認（失敗したジョブの行を展開して最初のエラーを確認）
  - 失敗が出た際は該当ワークフローの「View workflow file」からどのステップで失敗したかを特定

## 4) もし次に失敗するなら（診断／対処フロー）
1. 失敗ログの収集
   - Actions 実行ページの該当 run を開き、失敗したジョブとステップのログをコピーして共有
2. 代表的な失敗パターンと初期対処
   - stylelint / ESLint
     - ローカルで同じコマンドを実行して再現: `npm run lint` / `npm run lint:style` / `npm run lint:js`
     - 自動修正可能なら `--fix` を実行してコミット
     - ルールが厳しすぎる場合はルール緩和か `.stylelintignore` / `.eslintignore` の調整を検討
   - Nuxt generate が失敗
     - ログで具体的なエラー（モジュール missing / runtime error）を確認
     - `nuxt generate --force-build` をローカルで試し、 environment variables（GOOGLE_ANALYTICS_ID など）や Node バージョン不整合がないか確認
   - Dependency Review / Dependency graph 関連
     - API レスポンスやワークフローの出力で dependency-graph 未有効メッセージが出ているか確認
     - 未有効ならワークフロー内で skip する分岐は正しく動いているか確認
3. 追加的な短期対応（アンブロック）
   - lint のみ一時的に許容（非推奨）: `npm run lint:style || true`（CI でのみ一時使用）
   - 生成のみを最小で通してデプロイ: `nuxt generate --force-build` を使う
4. 必要な情報を求める（私が続けて調べるために必要なもの）
   - 直近の失敗 run の URL（Actions run のページ）
   - ローカルでの再現ログ（`npm run lint` の出力）

## 5) 変更を Wiki に反映しました（代替）
- GitHub Wiki（UI の Wiki ページ）に直接書き込む権限はこの自動ツールでは扱えないため、同等の内容を `docs/CI-runbook.md` として追加しました。必要なら私が別 PR で GitHub Wiki（.wiki repo）へ反映する手順も実行できます。

ファイル: `docs/CI-runbook.md` (このファイル)
コミットメッセージ: `Add CI runbook and PR#32 summary to docs (wiki)`

## 6) 次に私がやること（あなたの指示に応じて）
- 継続監視: 新しい Actions run が失敗したら、そのログを解析して原因特定と修正案を作成します
- 追加反映: この docs ファイルを実際の GitHub Wiki にコピー（要承認）
- 直接修正: さらなる lint ルール緩和や generate のパッチを作成し、PR を出せます

---
更新が必要な点や、Wiki を実際に GitHub Wiki へ反映してほしい場合、どのブランチに push してほしいか（`main` へ直接コミットで良いか、それとも feature ブランチ経由の PR にするか）を教えてください。