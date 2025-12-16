module Public::NotificationsHelper
  def notification_message(notification)
    case notification.notif_type
    when "topic_post"
      "参加中コミュニティに新しい投稿があります"
    when "review_comment"
      "新しいコメントが届きました"
    when "followee_review"
      review = notification.notifiable
      "#{h(review.user&.nickname)}さんが新しいゲームレビューを投稿しました"
    when "topic_membership_request"
      topic = notification.notifiable
      %Q(<strong class="text-success">参加申請</strong>が届きました).html_safe
    when "topic_membership_approved"
      topic = notification.notifiable
      %Q(参加申請が<span class="text-success">承認</span>されました).html_safe
    when "topic_membership_rejected"
      topic = notification.notifiable
      %Q(参加申請が<span class="text-danger">拒否</span>されました).html_safe
    else
      "新着通知"
    end
  end

  def notification_topic(notification)
    notifiable = notification.notifiable

    if notifiable.is_a?(Topic)
      notifiable
    elsif notifiable.respond_to?(:topic)
      notifiable.topic
    else
      nil
    end
  end

  # 通知が指す「トピック名（文字列）」を返す
  def notification_topic_title(notification)
    topic = notification_topic(notification)
    topic&.title || "トピック"
  end

  # 通知に関連する「トピック詳細画面へのパス」も取得できるヘルパー
  def notification_topic_path(notification)
    topic = notification_topic(notification)
    return nil unless topic && topic.forum

    forum_topic_path(topic.forum, topic)
  end
end