class AddUniqueIndexToGenresName < ActiveRecord::Migration[6.1]
  def change
    add_index :genres, :name, unique: true
  end
end
