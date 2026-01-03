# 自然言語の求人検索クエリをLLMで解析し、構造化データに変換するサービス
#
# @example
#   service = JobSearchParserService.new("都内で年収800万以上のRailsエンジニア")
#   result = service.parse
#   jobs = Job.hybrid_search(result[:keyword], **result[:filters])
class JobSearchParserService
  # @param query [String] 自然言語の検索クエリ
  def initialize(query)
    @query = query
    @client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])
  end

  # クエリを解析して構造化データに変換する
  #
  # @return [Hash] 解析結果
  #   - keyword [String] ベクトル検索用のキーワード
  #   - filters [Hash] SQL絞り込み条件
  #     - salary [Integer, nil] 最低年収（万円単位）
  #     - title [String, nil] タイトル（部分一致）
  #     - job_category [String, nil] 職種カテゴリ
  #     - business_type [String, nil] 事業種別
  #     - location [String, nil] 所在地
  #     - limit [Integer, nil] 取得件数
  def parse
    response = @client.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: [
          {
            role: "system",
            content: system_prompt
          },
          {
            role: "user",
            content: @query
          }
        ],
        response_format: { type: "json_object" },
        temperature: 0.3 # 安定した出力のため低めに設定
      }
    )

    result = JSON.parse(response.dig("choices", 0, "message", "content"))
    normalize_result(result)
  rescue => e
    # エラー時はデフォルト値を返す
    Rails.logger.error("JobSearchParserService parse error: #{e.message}")
    {
      keyword: @query,
      filters: {}
    }
  end

  private

  # システムプロンプト
  # @return [String]
  def system_prompt
    <<~PROMPT
      あなたは求人検索クエリを解析する専門家です。
      ユーザーの自然言語による検索文を解析し、以下のJSON形式で構造化データを返してください。

      # 利用可能な職種カテゴリ（job_category）
      #{Job.distinct.pluck(:job_category).compact.sort.join(', ')}

      # 利用可能な事業種別（business_type）
      #{Job.distinct.pluck(:business_type).compact.sort.join(', ')}

      # 出力JSON形式
      {
        "keyword": "ベクトル検索用のキーワード（職種や技術スキルなど意味的に重要な部分）",
        "filters": {
          "salary": 最低年収（万円単位の整数、指定がなければnull）,
          "title": "タイトルに含まれるべき文字列（指定がなければnull）",
          "job_category": "上記リストから最も近い職種カテゴリ（指定がなければnull）",
          "business_type": "上記リストから最も近い事業種別（指定がなければnull）",
          "location": "所在地（都道府県または市区町村レベル、指定がなければnull）",
          "limit": 取得件数（指定がなければnull、デフォルトは5件）
        }
      }

      # 解析のポイント
      - keyword: ユーザーが探している職種の本質や必要なスキルを抽出（例: "Railsエンジニア" → "Rails エンジニア サーバーサイド開発"）
      - salary: "年収800万" → 800、"500万以上" → 500、金額表記がなければnull
      - job_category: 検索文から推測される職種カテゴリを上記リストから選択（完全一致でなくても良い）
      - business_type: 「児童発達支援」「就労支援」などのキーワードがあれば対応する事業種別を選択
      - location: "都内" → "東京都", "渋谷" → "渋谷区", "横浜" → "横浜市"など、具体的な地名に変換
      - 指定がない項目はnullにする（空文字列ではなくnull）

      # 例
      入力: "都内で年収800万以上のRailsエンジニア"
      出力:
      {
        "keyword": "Rails エンジニア サーバーサイド開発 Ruby",
        "filters": {
          "salary": 800,
          "title": null,
          "job_category": "IT・エンジニア職",
          "business_type": null,
          "location": "東京都",
          "limit": null
        }
      }

      入力: "児童発達支援の保育士を探しています"
      出力:
      {
        "keyword": "保育士 児童 発達支援 子ども",
        "filters": {
          "salary": null,
          "title": "保育士",
          "job_category": "福祉専門職",
          "business_type": "児童発達支援",
          "location": null,
          "limit": null
        }
      }

      必ずJSON形式のみを返してください。説明文は不要です。
    PROMPT
  end

  # 解析結果を正規化する
  # @param result [Hash] LLMからの生のレスポンス
  # @return [Hash] 正規化された結果
  def normalize_result(result)
    filters = result["filters"] || {}

    # nullまたは空文字列の項目を除外
    normalized_filters = filters.compact.reject { |_, v| v.to_s.strip.empty? }

    {
      keyword: result["keyword"] || @query,
      filters: normalized_filters.symbolize_keys
    }
  end
end
