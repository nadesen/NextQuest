class Like < ApplicationRecord
  belongs_to :user
  # likeable_id を Review の id として扱う設計
  belongs_to :review, foreign_key: 'likeable_id', class_name: 'Review', optional: true, counter_cache: :likes_count

  validates :user_id, presence: true
  validates :likeable_id, presence: true
  validates_uniqueness_of :likeable_id, scope: :user_id
end
