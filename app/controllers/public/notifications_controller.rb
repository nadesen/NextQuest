class Public::NotificationsController < ApplicationController
  before_action :authenticate_user!

  def index
    notifications = current_user.notifications.where(read: false).order(created_at: :desc)
    if defined?(Kaminari)
      @topic_notifications = notifications.where(notif_type: ["topic_post", "topic_membership_request", "topic_membership_approved", "topic_membership_rejected"])
                                         .page(params[:topic_page]).per(10)
      @review_comment_notifications = notifications.where(notif_type: "review_comment")
                                                   .page(params[:review_comment_page]).per(10)
      @followee_review_notifications = notifications.where(notif_type: "followee_review")
                                                    .page(params[:followee_review_page]).per(10)
    elsif defined?(WillPaginate)
      @topic_notifications = notifications.where(notif_type: ["topic_post", "topic_membership_request", "topic_membership_approved", "topic_membership_rejected"])
                                         .paginate(page: params[:topic_page], per_page: 10)
      @review_comment_notifications = notifications.where(notif_type: "review_comment")
                                                   .paginate(page: params[:review_comment_page], per_page: 10)
      @followee_review_notifications = notifications.where(notif_type: "followee_review")
                                                    .paginate(page: params[:followee_review_page], per_page: 10)
    else
      @topic_notifications = notifications.where(notif_type: ["topic_post", "topic_membership_request", "topic_membership_approved", "topic_membership_rejected"]).limit(10)
      @review_comment_notifications = notifications.where(notif_type: "review_comment").limit(10)
      @followee_review_notifications = notifications.where(notif_type: "followee_review").limit(10)
    end
  end

  def update
    notification = current_user.notifications.find(params[:id])
    notification.update(read: true)
    # 通知の種類に応じてリダイレクト先を変更
    case notification.notif_type
    when "topic_membership_approved", "topic_membership_rejected"
      tm = notification.notifiable
      topic = tm&.topic
      forum = topic&.forum
      if topic && forum
        redirect_to forum_topic_path(forum, topic) and return
      end
    when "topic_post"
      post = notification.notifiable
      if post&.respond_to?(:topic) && post.topic && post.topic.forum
        redirect_to forum_topic_path(post.topic.forum, post.topic) and return
      end
    when "review_comment"
      comment = notification.notifiable
      if comment&.respond_to?(:review) && comment.review
        redirect_to review_path(comment.review) and return
      end
    when "followee_review"
      review = notification.notifiable
      redirect_to review_path(review) and return if review
    when "topic_membership_request"
      req = notification.notifiable
      topic = req&.topic
      forum = topic&.forum
      # トピックのメンバー一覧へ
      if topic && forum
        redirect_to forum_topic_topic_members_path(forum, topic) and return
      end
    end
    # どれにも当てはまらない場合
    redirect_back fallback_location: notifications_path
  end
end