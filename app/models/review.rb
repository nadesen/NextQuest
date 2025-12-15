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

  # フォローしているユーザーにレビュー作成を通知する
  after_create :notify_followers

  validates :title, presence: true
  validates :play_time, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :rating, presence: true, numericality: { greater_than_or_equal_to: 0.5, less_than_or_equal_to: 5 }
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

  # 実在する作成者(User)オブジェクトがあればそれを返す
  def author
    user if respond_to?(:user) && user.present?
  end

  # 表示用の作成者名を返す
  # - author が存在すれば nickname/name等を優先して返す
  # - author が無くても user_id が残っていれば「削除されたユーザー」を返す
  # - それ以外は「不明」
  def author_name
    if author.present?
      author.nickname.presence || author.name.presence || 'ユーザー'
    elsif respond_to?(:user_id) && user_id.present?
      '削除されたユーザー'
    else
      '不明'
    end
  end

  # 表示時にプロフィールへのリンクを付けてよいか（User オブジェクトが存在する場合のみ true）
  def author_link?
    author.present?
  end

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
