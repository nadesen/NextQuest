class AddUniqueIndexToPlatformsName < ActiveRecord::Migration[6.1]
  def change
    add_index :platforms, :name, unique: true
  end
end
