class Review < ApplicationRecord
  belongs_to :user
  belongs_to :platform
  belongs_to :genre
  validates :title, presence: true
  validates :play_time, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :rating, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }
  validates :content, presence: true, length: { maximum: 2000 }
  

end
