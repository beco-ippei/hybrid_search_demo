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
end
