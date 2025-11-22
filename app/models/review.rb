class Review < ApplicationRecord
  belongs_to :user
  belongs_to :platform
  belongs_to :genre
  has_many :review_comments, dependent: :destroy

  # Review に対するいいね
  # likes の外部キーは likeable_id を使う設計なので明示
  has_many :likes, foreign_key: 'likeable_id', dependent: :destroy

  # いいねをしたユーザー一覧を取得するための関連付け
  has_many :liked_users, through: :likes, source: :user

  validates :title, presence: true
  validates :play_time, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :rating, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }
  validates :content, presence: true, length: { maximum: 2000 }
  
  def self.search_for(content, method)
    return none if content.blank?

    pattern =
      case method
      when 'perfect'
        content
      when 'forward'
        "#{sanitize_sql_like(content)}%"
      when 'backward'
        "%#{sanitize_sql_like(content)}"
      else
        "%#{sanitize_sql_like(content)}%"
      end

    if method == 'perfect'
      where('title = ? OR content = ?', content, content)
    else
      where('title LIKE ? OR content LIKE ?', pattern, pattern)
    end
  end

end
