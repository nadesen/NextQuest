class AddUniqueIndexToGenresName < ActiveRecord::Migration[6.1]
  def change
    unless index_exists?(:genres, :name)
      add_index :genres, :name, unique: true
    end
  end
end
