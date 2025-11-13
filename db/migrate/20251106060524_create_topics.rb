class CreateTopics < ActiveRecord::Migration[6.1]
  def change
    create_table :topics do |t|
      t.integer :forum_id, null: false, index: true
      t.integer :creator_id, null: false, index: true
      t.string :title, null: false, index: true
      t.text :description
      t.boolean :locked, null: false, index: true, default: false  # 投稿禁止用
      t.integer :posts_count, null: false, default: 0              # 投稿数
      t.integer :views_count, null: false, default: 0              # 閲覧数

      t.timestamps
    end
  end
end
