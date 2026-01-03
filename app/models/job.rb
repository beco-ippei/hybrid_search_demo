class Job < ApplicationRecord
  # neighbor gem の設定（コサイン類似度を使う）
  has_neighbors :embedding

  # 保存前に自動でベクトル化
  before_save :generate_embedding, if: -> { description_changed? || job_category_changed? || business_type_changed? || location_changed? }

  # @return [void]
  def generate_embedding
    client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])

    # タイトル、職種カテゴリ、事業種別、所在地、仕事内容を結合してベクトル化
    # これにより、各属性が検索クエリとマッチしやすくなる
    combined_text = [
      "職種名: #{self.title}",
      ("職種カテゴリ: #{self.job_category}" if self.job_category.present?),
      ("事業種別: #{self.business_type}" if self.business_type.present?),
      ("勤務地: #{self.location}" if self.location.present?),
      "仕事内容: #{self.description}"
    ].compact.join("\n")

    response = client.embeddings(
      parameters: {
        model: "text-embedding-3-small",
        input: combined_text
      }
    )
    self.embedding = response.dig("data", 0, "embedding")
  end

  def self.vector_search(keyword_query)
    # 1. ユーザーの入力をベクトル化
    client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])
    response = client.embeddings(
      parameters: { model: "text-embedding-3-small", input: keyword_query }
    )
    query_vector = response.dig("data", 0, "embedding")

    # シンプルにベクトルだけで検索する場合:
    nearest_neighbors(:embedding, query_vector, distance: "cosine").limit(5)
  end

  # ■■■ ここがハイブリッド検索の核心 ■■■
  # @param keyword [String] 検索キーワード
  # @param args [Hash] 絞り込み条件
  # @option args [Integer] :salary 最低年収
  # @option args [String] :title タイトル（部分一致）
  # @option args [String] :job_category 職種カテゴリ（部分一致）
  # @option args [String] :business_type 事業種別（部分一致）
  # @option args [String] :location 所在地（部分一致）
  # @option args [Integer] :limit 取得件数（デフォルト: 5）
  # @return [ActiveRecord::Relation]
  def self.hybrid_search(keyword, **args)
    # 1. ユーザーの入力をベクトル化
    client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])
    response = client.embeddings(
      parameters: { model: "text-embedding-3-small", input: keyword }
    )
    query_vector = response.dig("data", 0, "embedding")

    # 2. SQL検索 (キーワード) と ベクトル検索 (意味) を組み合わせる
    query = all

    # 普通のSQL (最低年収などで絞り込みたい場合)
    if args[:salary].to_i.positive?
      query = query.where(min_salary: args[:salary].to_i..)
    end

    if args[:title].present?
      query = query.where("title LIKE ?", "%#{args[:title]}%")
    end

    if args[:job_category].present?
      query = query.where("job_category LIKE ?", "%#{args[:job_category]}%")
    end

    if args[:business_type].present?
      query = query.where("business_type LIKE ?", "%#{args[:business_type]}%")
    end

    if args[:location].present?
      query = query.where("location LIKE ?", "%#{args[:location]}%")
    end

    # ベクトル検索を適用
    limit_count = args[:limit] || 5
    query.nearest_neighbors(:embedding, query_vector, distance: "cosine").limit(limit_count)
  end

  # コンソールから呼びやすいようにするための hybrid_search のラッパー
  # @param query [String] 検索キーワード
  # @param args [Hash] 絞り込み条件
  # @return [nil]
  def self.hsearch(query, **args)
    results = Job.hybrid_search(query, **args).to_a

    puts "keyword:'#{query}', #{args}"
    results.each do |j|
      puts " > #{j.title} [#{j.job_category}] [#{j.business_type}] [#{j.location}]"
      puts "   年収:#{j.min_salary}万〜 / 類似度:#{j.neighbor_distance&.round(4)}"
    end
    nil
  end
end
