class AddLikesCountToReviews < ActiveRecord::Migration[6.1]
  def change
    unless column_exists?(:reviews, :likes_count)
      add_column :reviews, :likes_count, :integer, default: 0, null: false
    end
  end
end
