class Topic < ApplicationRecord
  # forum_id カラムに対する関連（counter_cache を使う場合は topics_count カラムが必要）
  # belongs_to による自動の presence 検証を無効にするため optional: true にします。
  belongs_to :forum, counter_cache: :topics_count, optional: true

  # 作成者（migration に creator_id がある場合）
  belongs_to :creator, class_name: 'User', foreign_key: 'creator_id', optional: true

  # トピックに紐づく投稿
  has_many :posts, dependent: :destroy, inverse_of: :topic, counter_cache: :posts_count
  
  # トピックのメンバーシップ（申請・参加管理）
  has_many :topic_memberships, dependent: :destroy
  has_many :all_members, through: :topic_memberships, source: :user
  # 実際に参加承認されたメンバーだけを members として扱う
  has_many :members, -> { where(topic_memberships: { status: 'approved' }) }, through: :topic_memberships, source: :user

  # バリデーション
  validates :title, presence: true
  # forum の検証は forum_id に対して一つだけ行い、メッセージを統一する
  validates :forum_id, presence: { message: 'を選択してください' }
  validates :description, length: { maximum: 500 }, allow_blank: true

  # 指定された forum_id が実際に存在するか確認したい場合は下を有効にする
  validate :forum_must_exist, if: -> { forum_id.present? }

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
      where('title = ? OR description = ?', content, content)
    else
      where('title LIKE ? OR description LIKE ?', pattern, pattern)
    end
  end

  # 実在する作成者(User)オブジェクトがあればそれを返す
  def author
    if respond_to?(:creator) && creator.present?
      creator
    elsif respond_to?(:user) && user.present?
      user
    else
      nil
    end
  end

  # 表示用の作成者名を返す
  def author_name
    if author.present?
      author.nickname.presence || author.name.presence || 'ユーザー'
    elsif respond_to?(:creator_id) && creator_id.present?
      '削除されたユーザー'
    elsif respond_to?(:user_id) && user_id.present?
      '削除されたユーザー'
    else
      '匿名'
    end
  end

  # プロフィールへリンクを張って良いか
  def author_link?
    author.present?
  end

  private

  def forum_must_exist
    errors.add(:forum_id, 'を選択してください') unless Forum.exists?(self.forum_id)
  end
end
