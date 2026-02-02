class Topic < ApplicationRecord
  # =========== 関連 ===========
  belongs_to :forum, counter_cache: :topics_count, optional: true
  belongs_to :creator, class_name: 'User', foreign_key: 'creator_id', optional: true

  has_many :posts, dependent: :destroy, inverse_of: :topic, counter_cache: :posts_count

  # メンバーシップ管理
  has_many :topic_memberships, dependent: :destroy
  has_many :all_members, through: :topic_memberships, source: :user
  has_many :members, -> { where(topic_memberships: { status: 'approved' }) },
           through: :topic_memberships, source: :user

  # =========== バリデーション ===========
  validates :title, presence: true
  validates :forum_id, presence: { message: 'を選択してください' }
  validates :description, length: { maximum: 500 }, allow_blank: true
  validate  :forum_must_exist, if: -> { forum_id.present? }

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
      where('title = ? OR description = ?', content, content)
    else
      where('title LIKE ? OR description LIKE ?', pattern, pattern)
    end
  end

  # =========== 表示用ユーザー名・リンク ===========
  def author
    if respond_to?(:creator) && creator.present?
      creator
    elsif respond_to?(:user) && user.present?
      user
    end
  end

  def author_name
    if author.present?
      author.nickname.presence || author.name.presence || 'ユーザー'
    elsif creator_id.present? || (respond_to?(:user_id) && user_id.present?)
      '削除されたユーザー'
    else
      '匿名'
    end
  end

  def author_link?
    author.present?
  end

  private

  # forum_idがDBに存在するか明示チェック
  def forum_must_exist
    errors.add(:forum_id, 'を選択してください') unless Forum.exists?(self.forum_id)
  end
end