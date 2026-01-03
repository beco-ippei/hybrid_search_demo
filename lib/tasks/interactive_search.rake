namespace :search do
  desc "自然言語検索のインタラクティブテスト"
  task interactive: :environment do
    puts "========================================="
    puts "🔍 自然言語求人検索（インタラクティブモード）"
    puts "========================================="
    puts "終了するには 'exit' または 'quit' を入力してください"
    puts ""

    loop do
      print "検索クエリを入力 > "
      query = $stdin.gets&.chomp

      break if query.nil? || query.match?(/^(exit|quit)$/i)
      next if query.strip.empty?

      puts "\n-----------------------------------------"
      puts "クエリ: #{query}"
      puts "-----------------------------------------"

      begin
        # 1. LLMで解析
        puts "⏳ LLMで解析中..."
        service = JobSearchParserService.new(query)
        result = service.parse

        puts "\n📊 解析結果:"
        puts "  keyword: #{result[:keyword]}"
        puts "  filters:"
        if result[:filters].any?
          result[:filters].each do |key, value|
            puts "    #{key}: #{value.inspect}"
          end
        else
          puts "    （絞り込み条件なし）"
        end

        # 2. ハイブリッド検索を実行
        puts "\n⏳ 検索中..."
        jobs = Job.hybrid_search(result[:keyword], **result[:filters])

        puts "\n🔍 検索結果:"
        if jobs.any?
          jobs.each_with_index do |job, idx|
            puts "  [#{idx + 1}] #{job.title}"
            puts "      職種: #{job.job_category} | 事業: #{job.business_type}"
            puts "      勤務地: #{job.location} | 年収: #{job.min_salary}万円〜"
            puts "      類似度: #{job.neighbor_distance&.round(4)}"
            puts ""
          end
          puts "  合計: #{jobs.size}件"
        else
          puts "  （該当する求人が見つかりませんでした）"
        end
      rescue => e
        puts "\n❌ エラーが発生しました: #{e.message}"
        puts e.backtrace.first(3).join("\n")
      end

      puts "\n========================================="
      puts ""
    end

    puts "\n終了しました"
  end
end
