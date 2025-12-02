class AddScoreToReviewComments < ActiveRecord::Migration[6.1]
  def change
    add_column :review_comments, :score, :decimal, precision: 5, scale: 3
  end
end
