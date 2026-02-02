class Review < ApplicationRecord
  belongs_to :user
  belongs_to :platform
  belongs_to :genre
  has_many :review_comments, dependent: :destroy

  # いいね（polymorphic: false 設計、likeable_idで紐付け）
  has_many :likes, foreign_key: 'likeable_id', dependent: :destroy
  has_many :liked_users, through: :likes, source: :user

  after_create :notify_followers

  validates :title, presence: true
  validates :play_time, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :rating, presence: true, numericality: { greater_than_or_equal_to: 0.5, less_than_or_equal_to: 5 }
  validates :content, presence: true, length: { maximum: 2000 }
  
  # =========== 検索 ===========
  def self.search_for(content, method)
    return none if content.blank?
    pattern = case method
              when 'perfect' then content
              when 'forward' then "#{sanitize_sql_like(content)}%"
              when 'backward' then "%#{sanitize_sql_like(content)}"
              else "%#{sanitize_sql_like(content)}%"
              end
    if method == 'perfect'
      where('title = ? OR content = ?', content, content)
    else
      where('title LIKE ? OR content LIKE ?', pattern, pattern)
    end
  end

  # =========== 表示・ユーザー名 ===========
  def author
    user if respond_to?(:user) && user.present?
  end

  def author_name
    if author.present?
      author.nickname.presence || author.name.presence || 'ユーザー'
    elsif user_id.present?
      '削除されたユーザー'
    else
      '不明'
    end
  end

  def author_link?
    author.present?
  end

  # レビュー作成後にフォロワーへ通知
  def notify_followers
    user.followers.each do |follower|
      unless Notification.exists?(user: follower, notifiable: self, notif_type: "followee_review", read: false)
        Notification.create!(
          user: follower,
          notifiable: self,
          notif_type: "followee_review"
        )
      end
    end
  end

  scope :approved, -> { where(approved: true) }

  def self.public_count
    approved.count
  end
end