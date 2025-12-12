module Public::NotificationsHelper
  def notification_message(notification)
    case notification.notif_type
    when "topic_post"
      post = notification.notifiable
      "参加中コミュニティ「#{post.topic&.title}」に新しい投稿があります"
    when "review_comment"
      comment = notification.notifiable
      "「#{comment.review&.title}」に新しいコメントが届きました"
    when "followee_review"
      review = notification.notifiable
      "#{review.user&.nickname || review.user&.name}さんが新しいレビュー「#{review.title}」を投稿しました"
    else
      "新着通知"
    end
  end
end