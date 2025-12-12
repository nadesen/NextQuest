class Public::NotificationsController < ApplicationController
  before_action :authenticate_user!

  def index
    notifications = current_user.notifications.where(read: false).order(created_at: :desc)
    @topic_notifications       = notifications.where(notif_type: "topic_post")
    @review_comment_notifications = notifications.where(notif_type: "review_comment")
    @followee_review_notifications = notifications.where(notif_type: "followee_review")
  end

  def update
    notification = current_user.notifications.find(params[:id])
    notification.update(read: true)
    # 通知の内容ごとに遷移先を振り分け
    case notification.notif_type
    when "topic_post"
      post = notification.notifiable
      if post.respond_to?(:topic) && post.topic
        redirect_to forum_topic_path(post.topic.forum, post.topic) and return
      end
    when "review_comment"
      comment = notification.notifiable
      if comment.respond_to?(:review) && comment.review
        redirect_to review_path(comment.review) and return
      end
    when "followee_review"
      review = notification.notifiable
      redirect_to review_path(review) and return if review
    end
    # どれにも当てはまらない場合
    redirect_back fallback_location: notifications_path
  end
end