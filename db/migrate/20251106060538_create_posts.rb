class CreatePosts < ActiveRecord::Migration[6.1]
  def change
    create_table :posts do |t|
      t.integer :topic_id, null: false, index: true
      t.integer :creator_id, null: false, index: true
      t.text :content, null: false                      # 投稿内容
      t.boolean :edited, null: false, default: false    # 編集済みフラグ
      t.integer :likes_count, null: false, default: 0   # いいね数

      t.timestamps
    end

    add_index :posts, :topic_id
    add_index :posts, :creator_id
  end
end
