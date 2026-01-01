# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

Rails 8.1.1 + PostgreSQL (pgvector) を使用したハイブリッド検索のデモアプリケーション。
OpenAI APIで生成した埋め込みベクトルと従来のSQL検索を組み合わせて、意味的な類似度とキーワードマッチの両方を活用した検索を実現している。

## コーディング規約

**重要**: このプロジェクトでは以下の規約を厳守すること：

- すべての会話、説明、Gitコミットメッセージは日本語で行う
- コード内のコメントも日本語で記述する
- メソッドにはYARD形式の型ヒントを必ずつける

## 環境構築

### 必須要件
- Ruby 3.4.0
- PostgreSQL (vector拡張機能が必要)
- OpenAI APIキー（.envファイルに`OPENAI_API_KEY`として設定）

### セットアップ手順
```bash
# 依存関係のインストール
bundle install

# データベースの作成とマイグレーション
bin/rails db:create
bin/rails db:migrate

# テストデータの投入
bin/rails import:jobs
```

## 主要なコマンド

### 開発サーバーの起動
```bash
bin/rails server
# または
bin/dev
```

### テストの実行
```bash
bin/rails test
bin/rails test:system  # システムテスト
```

### データベース操作
```bash
bin/rails db:migrate              # マイグレーション実行
bin/rails db:rollback             # 直前のマイグレーションをロールバック
bin/rails db:reset                # DBをリセットしてseedを実行
bin/rails import:jobs             # 求人テストデータの投入
```

### 静的解析・セキュリティチェック
```bash
bundle exec rubocop                # コードスタイルチェック
bundle exec brakeman              # セキュリティ脆弱性チェック
bundle exec bundler-audit         # Gemの脆弱性チェック
```

### Railsコンソールでのハイブリッド検索テスト
```ruby
# ベクトル検索のみ
Job.vector_search("エンジニア")

# ハイブリッド検索（意味検索 + 条件絞り込み）
Job.hsearch("デザイナー", salary: 5000000)

# タイトルでの絞り込みも可能
Job.hsearch("支援", title: "児童")
```

## アーキテクチャ

### ハイブリッド検索の仕組み

このアプリの核心は`app/models/job.rb`の`hybrid_search`メソッドにある。以下の2つの検索手法を組み合わせている：

1. **ベクトル検索**（意味的類似度）
   - OpenAI `text-embedding-3-small`モデルでテキストを1536次元のベクトルに変換
   - pgvectorとneighbor gemでコサイン類似度を計算
   - 「エンジニア」と入力すれば「Webエンジニア」「UI/UXデザイナー」など関連職種も検索できる

2. **SQL検索**（厳密な条件絞り込み）
   - `min_salary`での年収フィルタリング
   - `title`のLIKE検索
   - 従来のRDBMSの強みを活かした正確な絞り込み

### ベクトル生成のタイミング

- `Job`モデルの`before_save`コールバックで自動的に埋め込みベクトルを生成
- `description`が変更された場合のみOpenAI APIを呼び出す（コスト最適化）
- タイトルと説明文を結合した形式でベクトル化することで、職種名の重要性を強調

### データベーススキーマ

`jobs`テーブル:
- `title`: 職種名（string）
- `description`: 仕事内容（text）
- `min_salary`: 最低年収（integer）
- `embedding`: 埋め込みベクトル（vector型、次元数1536）

PostgreSQLのvector拡張機能を有効化する必要がある（`db/migrate/20251230033025_enable_vector_extension.rb`）。

## 主要なGem

- `ruby-openai`: OpenAI APIクライアント（埋め込みベクトル生成用）
- `neighbor`: PostgreSQL pgvectorのRubyラッパー（ベクトル検索用）
- `dotenv-rails`: 環境変数管理（開発・テスト環境）

## テストデータ

`lib/tasks/import_jobs.rake`にLITALICO風の求人データ作成タスクがある：
- テック職（Webエンジニア、UI/UXデザイナー）
- 専門職（児童指導員、就労支援員）
- ビジネス職（インサイドセールス、教室長）

これらのデータでベクトル検索の精度や、年収での絞り込み機能をテストできる。
