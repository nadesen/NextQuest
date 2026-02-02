class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # ===== 各種関連 =====
  has_many :review_comments, dependent: :destroy
  has_many :likes, dependent: :destroy

  # いいねしたレビュー(Review)
  has_many :liked_reviews, through: :likes, source: :review

  # トピックメンバーシップ系
  has_many :topic_memberships, dependent: :destroy
  has_many :joined_topics, through: :topic_memberships, source: :topic

  # フォロー機能
  has_many :following_relationships,
            class_name: 'Follow',
            foreign_key: 'follower_id',
            dependent: :destroy
  has_many :followings,
            through: :following_relationships,
            source: :followed

  has_many :follower_relationships,
            class_name: 'Follow',
            foreign_key: 'followed_id',
            dependent: :destroy
  has_many :followers,
            through: :follower_relationships,
            source: :follower

  # 通知
  has_many :notifications, dependent: :destroy

  # ====== バリデーション ======
  validates :name,     presence: true, length: { maximum: 30 }
  validates :nickname, presence: true, length: { maximum: 50 }

  # ゲストユーザー用の定数
  GUEST_USER_EMAIL = "guest@example.com"

  # ----- ゲスト取得 -----
  def self.guest
    find_or_create_by!(email: GUEST_USER_EMAIL) do |user|
      user.password = SecureRandom.urlsafe_base64
      user.name = user.nickname = "ゲストユーザー"
    end
  end

  def guest_user?
    email == GUEST_USER_EMAIL
  end

  # ----- Devise サスペンド対応 -----
  def active_for_authentication?
    super && !suspended?
  end

  def inactive_message
    suspended? ? :suspended : super
  end

  # ----- 検索 -----
  # method: 'perfect' | 'forward' | 'backward' | 'partial'
  def self.search_for(content, method)
    return none if content.blank?
    pattern = case method
              when 'perfect' then content
              when 'forward' then "#{sanitize_sql_like(content)}%"
              when 'backward' then "%#{sanitize_sql_like(content)}"
              else "%#{sanitize_sql_like(content)}%"
              end

    if method == 'perfect'
      where('nickname = :q OR name = :q OR email = :q OR profile_text = :q', q: content)
    else
      where('nickname LIKE :p OR name LIKE :p OR email LIKE :p OR profile_text LIKE :p', p: pattern)
    end
  end

  # ----- フォロー操作 -----
  def follow(other_user)
    return if other_user.nil? || self == other_user
    following_relationships.find_or_create_by(followed_id: other_user.id)
  end

  def unfollow(other_user)
    following_relationships.find_by(followed_id: other_user.id)&.destroy
  end

  def following?(other_user)
    followings.exists?(other_user&.id)
  end

  # ----- フィード生成例（フォロー中ユーザー+自分のレビュー） -----
  def feed_reviews
    Review.where(user_id: (followings.pluck(:id) + [id]))
  end
end