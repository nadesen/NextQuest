class Topic < ApplicationRecord
  # forum_id カラムに対する関連（counter_cache を使う場合は topics_count カラムが必要）
  # belongs_to による自動の presence 検証を無効にするため optional: true にします。
  belongs_to :forum, counter_cache: :topics_count, optional: true

  # 作成者（migration に creator_id がある場合）
  belongs_to :creator, class_name: 'User', foreign_key: 'creator_id', optional: true

  # トピックに紐づく投稿
  has_many :posts, dependent: :destroy, inverse_of: :topic, counter_cache: :posts_count

  # バリデーション
  validates :title, presence: true
  # forum の検証は forum_id に対して一つだけ行い、メッセージを統一する
  validates :forum_id, presence: { message: 'を選択してください' }
  validates :description, length: { maximum: 500 }, allow_blank: true

  # 指定された forum_id が実際に存在するか確認したい場合は下を有効にする
  validate :forum_must_exist, if: -> { forum_id.present? }

  def self.search_for(content, method)
    return none if content.blank?

    case method
    when 'perfect'
      where(title: content)
    when 'forward'
      where('title LIKE ?', "#{sanitize_sql_like(content)}%")
    when 'backward'
      where('title LIKE ?', "%#{sanitize_sql_like(content)}")
    else # partial
      where('title LIKE ?', "%#{sanitize_sql_like(content)}%")
    end
  end

  private

  def forum_must_exist
    errors.add(:forum_id, 'を選択してください') unless Forum.exists?(self.forum_id)
  end
end
