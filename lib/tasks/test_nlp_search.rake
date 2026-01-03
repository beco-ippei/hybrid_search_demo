namespace :test do
  desc "自然言語検索のテスト"
  task nlp_search: :environment do
    test_queries = [
      "都内で年収800万以上のRailsエンジニア",
      "児童発達支援の保育士を探しています",
      "渋谷でWebマーケティングの仕事",
      "就労支援員 神奈川県",
      "年収500万以上のサービス管理責任者"
    ]

    puts "========================================="
    puts "自然言語検索テスト"
    puts "========================================="

    test_queries.each_with_index do |query, idx|
      puts "\n[#{idx + 1}] クエリ: #{query}"
      puts "-----------------------------------------"

      # 1. LLMで解析
      service = JobSearchParserService.new(query)
      result = service.parse

      puts "📊 解析結果:"
      puts "  keyword: #{result[:keyword]}"
      puts "  filters: #{result[:filters].inspect}"

      # 2. ハイブリッド検索を実行
      jobs = Job.hybrid_search(result[:keyword], **result[:filters])

      puts "\n🔍 検索結果（上位3件）:"
      if jobs.any?
        jobs.limit(3).each do |job|
          puts "  > #{job.title}"
          puts "    [#{job.job_category}] [#{job.business_type}] [#{job.location}]"
          puts "    年収:#{job.min_salary}万〜 / 類似度:#{job.neighbor_distance&.round(4)}"
        end
      else
        puts "  （該当なし）"
      end

      puts "\n"
      sleep 1 # API rate limit対策
    end

    puts "========================================="
    puts "テスト完了"
    puts "========================================="
  end
end
