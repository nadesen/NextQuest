class CreateFollows < ActiveRecord::Migration[6.1]
  def change
    create_table :follows do |t|
      t.integer :follower_id, null: false, index: true  # フォロワーのユーザーID
      t.integer :followed_id, null: false, index: true  # フォローされているユーザーID

      t.timestamps
    end

    add_index :follows, [:follower_id, :followed_id], unique: true
  end
end
