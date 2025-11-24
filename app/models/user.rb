class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  has_many :review_comments, dependent: :destroy
  # ユーザーが行ったいいねを保持
  has_many :likes, dependent: :destroy
  # ユーザーがいいねしたレビュー一覧取得用
  has_many :liked_reviews, through: :likes, source: :review

  # メンバーシップ機能用
  has_many :topic_memberships, dependent: :destroy
  has_many :joined_topics, through: :topic_memberships, source: :topic

  # --- フォロー機能 ---
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

  validates :name, presence: true, length: { maximum: 30 }
  validates :nickname, presence: true, length: { maximum: 50 }

  # ゲストユーザー用の定数
  GUEST_USER_EMAIL = "guest@example.com"

  def self.guest
    find_or_create_by!(email: GUEST_USER_EMAIL) do |user|
      user.password = SecureRandom.urlsafe_base64
      user.name = "guestuser"
    end
  end

  # suspended が true の場合はログイン不可にする
  def active_for_authentication?
    super && !suspended?
  end

  # ログイン不可（active_for_authentication? が false）の理由を返す
  # :suspended を返すと Devise は devise.failure.suspended の i18n を使います
  def inactive_message
    suspended? ? :suspended : super
  end

  # 検索メソッド（searches_controller から呼び出す）
  # content: 検索語
  # method: 'perfect' | 'forward' | 'backward' | 'partial'
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
      where('nickname = :q OR name = :q OR email = :q OR profile_text = :q', q: content)
    else
      where('nickname LIKE :p OR name LIKE :p OR email LIKE :p OR profile_text LIKE :p', p: pattern)
    end
  end

  # ユーザーをフォローする
  def follow(other_user)
    return if other_user.nil? || self == other_user
    following_relationships.find_or_create_by(followed_id: other_user.id)
  end

  # フォロー解除
  def unfollow(other_user)
    rel = following_relationships.find_by(followed_id: other_user.id)
    rel&.destroy
  end

  # フォローしているか
  def following?(other_user)
    followings.exists?(other_user&.id)
  end

  # フィードを取得する（例: フォローしているユーザーのレビューや投稿をまとめる）
  def feed_reviews
    Review.where(user_id: (followings.pluck(:id) + [id]))
  end

end
