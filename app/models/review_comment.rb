class ReviewComment < ApplicationRecord
  belongs_to :user,   optional: true
  belongs_to :review

  after_create :notify_review_owner

  validates :comment, presence: true, length: { maximum: 1000 }

  # =========== 表示用投稿者関連 ===========
  def author
    user if respond_to?(:user) && user.present?
  end

  def author_name
    if author.present?
      author.nickname.presence || author.name.presence || author.email.presence || 'ユーザー'
    elsif user_id.present?
      '削除されたユーザー'
    else
      '匿名'
    end
  end

  def author_link?
    author.present?
  end

  # レビュー所有者に通知（自分がしたコメント除外）
  def notify_review_owner
    owner = review.user
    return if owner == user
    unless Notification.exists?(user: owner, notifiable: review, notif_type: "review_comment", read: false)
      Notification.create!(
        user: owner,
        notifiable: review,
        notif_type: "review_comment"
      )
    end
  end
end