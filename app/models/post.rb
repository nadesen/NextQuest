class Post < ApplicationRecord
  belongs_to :topic, counter_cache: :posts_count
  belongs_to :creator, class_name: 'User', foreign_key: 'creator_id', optional: true

  after_create :notify_topic_members

  validates :content, presence: true

  # =========== 投稿者・表示系 ===========
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
    elsif (respond_to?(:creator_id) && creator_id.present?) || (respond_to?(:user_id) && user_id.present?)
      '削除されたユーザー'
    else
      '匿名'
    end
  end

  def author_link?
    author.present?
  end

  # トピック参加メンバー・オーナー等へ通知
  def notify_topic_members
    return unless topic.present?
    receivers = topic.members.to_a
    receivers << topic.creator if topic.respond_to?(:creator) && topic.creator.present?
    receivers.uniq!
    receivers.delete(self.author) if self.author.present? # 投稿者自身は通知対象外

    receivers.each do |member|
      unless Notification.exists?(user: member, notifiable: topic, notif_type: "topic_post", read: false)
        Notification.create!(
          user: member,
          notifiable: topic,
          notif_type: "topic_post"
        )
      end
    end
  end
end