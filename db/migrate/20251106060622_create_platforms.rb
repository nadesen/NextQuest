class CreatePlatforms < ActiveRecord::Migration[6.1]
  def change
    create_table :platforms do |t|
      t.string :name, null: false, index: true          # プラットフォーム名

      t.timestamps
    end
    add_index :platforms, :name, unique: true unless index_exists?(:platforms, :name)
  end
end
