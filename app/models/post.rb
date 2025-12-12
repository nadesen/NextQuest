class Post < ApplicationRecord
  belongs_to :topic, counter_cache: :posts_count
  belongs_to :creator, class_name: 'User', foreign_key: 'creator_id', optional: true

  # トピックのメンバーに投稿作成を通知する
  after_create :notify_topic_members

  validates :content, presence: true

  # 投稿者（creator または user）を返す（存在すれば User オブジェクト）
  def author
    if respond_to?(:creator) && creator.present?
      creator
    elsif respond_to?(:user) && user.present?
      user
    else
      nil
    end
  end

  # 表示用の投稿者名を返す
  # - author が存在すれば nickname/name 等を優先して返す
  # - author が無くても creator_id/user_id が残っていれば「削除されたユーザー」を返す
  # - それ以外は「匿名」
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

  # 表示時にプロフィールへのリンクを付けてよいか（User オブジェクトが存在する場合のみ true）
  def author_link?
    author.present?
  end

  def notify_topic_members
    return unless topic.present?
    notified_users = topic.members.to_a
    notified_users << topic.creator if topic.respond_to?(:creator) && topic.creator.present?
    notified_users.uniq!
    notified_users.delete(self.author) if self.author.present?
    notified_users.each do |member|
      Notification.create!(
        user: member,
        notifiable: self,
        notif_type: "topic_post"
      )
    end
  end

end