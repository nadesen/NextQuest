class AddUniqueIndexToForumsTitle < ActiveRecord::Migration[6.1]
  def change
    add_index :forums, :title, unique: true
  end
end
