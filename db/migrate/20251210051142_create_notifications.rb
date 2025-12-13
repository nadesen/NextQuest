class CreateNotifications < ActiveRecord::Migration[6.1]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.references :notifiable, polymorphic: true, null: false
      t.boolean :read, null: false, default: false
      t.string :notif_type, null: false, default: ""
      t.timestamps
    end
  end
end
