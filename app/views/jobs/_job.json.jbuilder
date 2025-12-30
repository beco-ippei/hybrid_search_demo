json.extract! job, :id, :title, :description, :min_salary, :embedding, :#, :OpenAIの次元数, :created_at, :updated_at
json.url job_url(job, format: :json)
