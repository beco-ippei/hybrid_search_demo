class SearchController < ApplicationController
  # GET /search
  # 自然言語検索のトップページ
  def index
    # 全件データを取得（右カラムに表示）
    @all_jobs = Job.order(created_at: :desc)

    return unless params[:query].present?

    @query = params[:query]
    @show_debug = params[:debug] == "true"

    begin
      # 1. LLMでクエリを解析
      service = JobSearchParserService.new(@query)
      @parse_result = service.parse

      # 2. ハイブリッド検索を実行
      @jobs = Job.hybrid_search(
        @parse_result[:keyword],
        **@parse_result[:filters]
      )

      # 検索成功
      @search_performed = true
    rescue => e
      # エラー時は空の結果を返す
      Rails.logger.error("Search error: #{e.message}")
      @error_message = "検索中にエラーが発生しました。もう一度お試しください。"
      @jobs = Job.none
      @search_performed = true
    end
  end

  # GET /search/advanced
  # 詳細検索ページ
  def advanced
    # 全件データを取得（右カラムに表示）
    @all_jobs = Job.order(created_at: :desc)

    # 検索条件の選択肢を取得
    @job_categories = Job.distinct.pluck(:job_category).compact.sort
    @business_types = Job.distinct.pluck(:business_type).compact.sort
    @locations = Job.distinct.pluck(:location).compact.sort

    return unless search_params_present?

    begin
      # パラメータから検索条件を構築
      filters = build_filters

      # ハイブリッド検索を実行
      keyword = params[:keyword].presence || ""
      @jobs = Job.hybrid_search(keyword, **filters)

      # 検索成功
      @search_performed = true
    rescue => e
      # エラー時は空の結果を返す
      Rails.logger.error("Advanced search error: #{e.message}")
      @error_message = "検索中にエラーが発生しました。もう一度お試しください。"
      @jobs = Job.none
      @search_performed = true
    end
  end

  private

  # 検索パラメータが存在するかチェック
  # @return [Boolean]
  def search_params_present?
    params[:keyword].present? ||
      params[:job_category].present? ||
      params[:business_type].present? ||
      params[:location].present? ||
      params[:min_salary].present?
  end

  # パラメータから検索フィルタを構築
  # @return [Hash]
  def build_filters
    filters = {}

    # 最低年収
    if params[:min_salary].present? && params[:min_salary].to_i > 0
      filters[:salary] = params[:min_salary].to_i
    end

    # 職種カテゴリ（配列の場合は最初の値を使用）
    if params[:job_category].present?
      category = params[:job_category].is_a?(Array) ? params[:job_category].first : params[:job_category]
      filters[:job_category] = category if category.present?
    end

    # 事業種別（配列の場合は最初の値を使用）
    if params[:business_type].present?
      business = params[:business_type].is_a?(Array) ? params[:business_type].first : params[:business_type]
      filters[:business_type] = business if business.present?
    end

    # 所在地（配列の場合は最初の値を使用）
    if params[:location].present?
      loc = params[:location].is_a?(Array) ? params[:location].first : params[:location]
      filters[:location] = loc if loc.present?
    end

    filters
  end
end
