class CreateGenres < ActiveRecord::Migration[6.1]
  def change
    create_table :genres do |t|
      t.string :name, null: false, index: true          # ジャンル名

      t.timestamps
    end

    add_index :genres, :name, unique: true unless index_exists?(:genres, :name)
  end
end
