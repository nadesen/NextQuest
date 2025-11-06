class CreateLikes < ActiveRecord::Migration[6.1]
  def change
    create_table :likes do |t|
      t.integer :user_id, null: false, index: true      # いいねをしたユーザーID
      t.integer :likeable_id, null: false, index: true  # いいね対象のレビューID

      t.timestamps
    end

    add_index :likes, [:user_id, :likeable_id], unique: true
  end
end
