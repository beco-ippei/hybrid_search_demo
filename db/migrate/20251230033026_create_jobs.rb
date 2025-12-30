class CreateJobs < ActiveRecord::Migration[8.1]
  def change
    create_table :jobs do |t|
      t.string :title
      t.text :description
      t.integer :min_salary
      t.vector :embedding, limit: 1536

      t.timestamps
    end
  end
end
