class ReviewComment < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :review

  # レビューの所有者にコメント作成を通知する
  after_create :notify_review_owner

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

  def notify_review_owner
    owner = review.user
    return if owner == user # 自コメントは通知不要
  
    # 「同じレビューに対する未読通知」が既にあれば作らない
    unless Notification.exists?(user: owner, notifiable: review, notif_type: "review_comment", read: false)
      Notification.create!(
        user: owner,
        notifiable: review,
        notif_type: "review_comment"
      )
    end
  end

end
