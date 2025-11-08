class Post < ApplicationRecord
  # topic_id, creator_id がマイグレーションにある想定
  belongs_to :topic, counter_cache: :posts_count
  belongs_to :creator, class_name: 'User', foreign_key: 'creator_id', optional: true

  validates :content, presence: true
end
