class EnableVectorExtension < ActiveRecord::Migration[8.1]
  def change
    enable_extension "vector" # これを追記
  end
end
