class ReviewComment < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :review

  validates :comment, presence: true, length: { maximum: 1000 }

  # 実在するユーザーオブジェクトがあれば返す
  def author
    user if respond_to?(:user) && user.present?
  end

  # 表示用の投稿者名
  def author_name
    if author.present?
      author.nickname.presence || author.name.presence || author.email.presence || 'ユーザー'
    elsif respond_to?(:user_id) && user_id.present?
      '削除されたユーザー'
    else
      '匿名'
    end
  end

  # プロフィールにリンクして良いか
  def author_link?
    author.present?
  end
end
