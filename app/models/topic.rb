class Topic < ApplicationRecord
  # forum_id カラムに対する関連（counter_cache を使う場合は topics_count カラムが必要）
  belongs_to :forum, counter_cache: :topics_count

  # 作成者（migration に creator_id がある場合）
  belongs_to :creator, class_name: 'User', foreign_key: 'creator_id', optional: true

  # トピックに紐づく投稿
  has_many :posts, dependent: :destroy, inverse_of: :topic, counter_cache: :posts_count

  # バリデーション
  validates :title, presence: true
  validates :forum, presence: true
end
