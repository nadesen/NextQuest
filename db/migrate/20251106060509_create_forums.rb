class CreateForums < ActiveRecord::Migration[6.1]
  def change
    create_table :forums do |t|
      t.string :title, null: false
      t.text :description
      t.boolean :public, null: false, index: true, default: true  # 公開・非公開設定
      t.integer :creator_id, index: true                          # 作成者ID
      t.integer :topics_count, null: false, default: 0            # トピック数
      t.integer :posts_count, null: false, default: 0             # 投稿数
      t.integer :position, null: false, index: true, default: 0   # 表示順序

      t.timestamps
    end
  end
end
