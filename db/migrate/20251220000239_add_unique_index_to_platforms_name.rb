class AddUniqueIndexToPlatformsName < ActiveRecord::Migration[6.1]
  def change
    unless index_exists?(:platforms, :name)
      add_index :platforms, :name, unique: true
    end
  end
end
