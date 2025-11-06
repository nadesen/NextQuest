class CreateReviews < ActiveRecord::Migration[6.1]
  def change
    create_table :reviews do |t|
      t.integer :user_id, null: false
      t.integer :platform_id, null: false
      t.integer :genre_id, null: false
      t.integer :rating, null: false                    # 評価点数
      t.string :title, null: false                      # レビュータイトル
      t.text :content, null: false                      # レビュー内容
      t.string :play_time                                # プレイ時間
      t.boolean :approved, null: false, default: true   # 承認済みフラグ
      t.integer :likes_count, null: false, default: 0   # いいね数

      t.timestamps
    end

    add_index :reviews, :user_id
    add_index :reviews, :platform_id
    add_index :reviews, :genre_id
  end
end
