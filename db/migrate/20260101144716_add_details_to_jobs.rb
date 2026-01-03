class AddDetailsToJobs < ActiveRecord::Migration[8.1]
  def change
    add_column :jobs, :job_category, :string
    add_column :jobs, :business_type, :string
    add_column :jobs, :location, :string
  end
end
