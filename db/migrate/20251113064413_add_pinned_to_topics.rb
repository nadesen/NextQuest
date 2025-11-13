class AddPinnedToTopics < ActiveRecord::Migration[6.1]
  def change
    add_column :topics, :pinned, :boolean, default: false, null: false
    add_index  :topics, :pinned
  end
end
