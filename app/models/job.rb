class Job < ApplicationRecord
  # neighbor gem の設定（コサイン類似度を使う）
  has_neighbors :embedding

  # 保存前に自動でベクトル化
  before_save :generate_embedding, if: -> { description_changed? }

  def generate_embedding
    client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])

    # 【修正点】 タイトルと本文を結合し、AIに「これは何のデータか」を明示するフォーマットにする
    # これにより "職種: 法人営業" という強いシグナルが先頭に来る
    combined_text = "職種名: #{self.title}\n仕事内容: #{self.description}"

    response = client.embeddings(
      parameters: {
        model: "text-embedding-3-small",
        input: combined_text # ここを combined_text に変更
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
  def self.hybrid_search(keyword, **args)
    # 1. ユーザーの入力をベクトル化
    client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])
    response = client.embeddings(
      parameters: { model: "text-embedding-3-small", input: keyword }
    )
    query_vector = response.dig("data", 0, "embedding")

    # 2. SQL検索 (キーワード) と ベクトル検索 (意味) を組み合わせる
    # 例: 「年収600万以上」かつ「ベクトルが近い順」

    query = all

    # 普通のSQL (最低年収などで絞り込みたい場合)
    if args[:salary].to_i.positive?
      query = query.where(min_salary: args[:salary].to_i..)
    end

    if args[:title].present?
      query = query.where("title LIKE ?", "%#{args[:title]}%")
    end

    # シンプルにベクトルだけで検索する場合:
    query.nearest_neighbors(:embedding, query_vector, distance: "cosine").limit(5)
  end

  def self.hsearch(query, **args)
    results = Job.hybrid_search(query, **args).to_a

    puts "keyword:'#{query}', #{args}"
    results.each do |j|
      # puts " > #{j.title} / dist:#{j.neighbor_distance}"
      puts " > #{j.title} / salary:#{j.min_salary} / dist:#{j.neighbor_distance}"
      # puts " > #{j.title} / salary:#{j.min_salary} / dist:-"
    end
    nil
  end
end
