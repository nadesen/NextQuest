class CreateTopicMemberships < ActiveRecord::Migration[6.1]
  def change
    create_table :topic_memberships do |t|
      t.integer :topic_id, null: false, index: true
      t.integer :user_id, null: false, index: true
      t.string  :status, null: false, default: 'pending', index: true
      t.integer :approved_by_id, index: true  # 承認したユーザー(admin/owner)
      t.timestamps
    end

    add_index :topic_memberships, [:topic_id, :user_id], unique: true
  end
end
