module Public::NotificationsHelper
  def notification_message(notification)
    case notification.notif_type
    when "topic_post"
      post = notification.notifiable
      "参加中コミュニティに新しい投稿があります"
    when "review_comment"
      comment = notification.notifiable
      "新しいコメントが届きました"
    when "followee_review"
      review = notification.notifiable
      "#{h(review.user&.nickname)}さんが新しいゲームレビューを投稿しました"
    when "topic_membership_request"
      req = notification.notifiable
      user_name = h(req.user&.nickname || 'ユーザー')
      topic_title = h(req.topic&.title)
      %Q(<span class="text-danger">#{user_name}さんが参加申請しました</span>).html_safe
    when "topic_membership_approved"
      req = notification.notifiable
      topic_title = h(req.topic&.title)
      %Q(参加申請が<span class="text-success">承認</span>されました).html_safe
    when "topic_membership_rejected"
      req = notification.notifiable
      topic_title = h(req.topic&.title)
      %Q(参加申請が<span class="text-danger">拒否</span>されました).html_safe
    else
      "新着通知"
    end
  end
end