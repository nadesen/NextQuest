class CreateForums < ActiveRecord::Migration[6.1]
  def change
    create_table :forums do |t|
      t.string :title, null: false
      t.text :description
      t.boolean :public, null: false, index: true, default: true  # 公開・非公開設定
      t.integer :creator_id, null: false, index: true
      t.integer :topics_count, null: false, default: 0            # トピック数
      t.integer :posts_count, null: false, default: 0             # 投稿数
      t.integer :position, null: false, index: true, default: 0   # 表示順序

      t.timestamps
    end

    add_index :forums, :creator_id
    add_index :forums, :position
    add_index :forums, :public
    add_index :forums, :title
  end
end
