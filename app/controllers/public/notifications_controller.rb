class Public::NotificationsController < ApplicationController
  before_action :authenticate_user!
  before_action :reject_guest_user!

  def index
    notifications = current_user.notifications.where(read: false).order(created_at: :desc)

    @topic_notifications         = filter_paginate_notifications(notifications, ["topic_post", "topic_membership_request", "topic_membership_approved", "topic_membership_rejected"], :topic_page)
    @review_comment_notifications = filter_paginate_notifications(notifications, "review_comment", :review_comment_page)
    @followee_review_notifications = filter_paginate_notifications(notifications, "followee_review", :followee_review_page)
  end

  def update
    notification = current_user.notifications.find(params[:id])
    notification.update(read: true)
    # 種類ごとにリダイレクト先を分ける
    redirect_to_notification(notification)
  end

  def batch_update
    type = params[:type]
    allowed_types = {
      "topic"          => ["topic_post"],
      "review_comment" => ["review_comment"],
      "followee_review" => ["followee_review"]
    }
    notif_types = allowed_types[type]
    if notif_types
      current_user.notifications.where(read: false, notif_type: notif_types).update_all(read: true)
      flash[:notice] = "選択した通知をすべて既読にしました。"
    else
      flash[:alert] = "この種類の通知は一括既読できません。"
    end
    redirect_back fallback_location: notifications_path
  end

  private

  def reject_guest_user!
    if current_user&.email == "guest@example.com"
      redirect_to root_path, alert: "ゲストユーザーは通知機能を利用できません。"
    end
  end

  # 通知タイプごとにページネートして返す
  def filter_paginate_notifications(scope, notif_type, page_param)
    query = scope.where(notif_type: notif_type)
    if defined?(Kaminari)
      query.page(params[page_param]).per(10)
    elsif defined?(WillPaginate)
      query.paginate(page: params[page_param], per_page: 10)
    else
      query.limit(10)
    end
  end

  # 各通知タイプに応じた遷移を統一的に処理する
  def redirect_to_notification(notification)
    case notification.notif_type
    when "topic_membership_approved", "topic_membership_rejected"
      tm    = notification.notifiable
      topic = tm.topic if tm.respond_to?(:topic)
      forum = topic&.forum
      return redirect_to forum_topic_path(forum, topic) if forum && topic
    when "topic_post"
      topic = notification.notifiable
      forum = topic&.forum
      return redirect_to forum_topic_path(forum, topic) if forum && topic
    when "review_comment"
      comment = notification.notifiable
      return redirect_to review_path(comment.review) if comment&.respond_to?(:review) && comment.review
    when "followee_review"
      review = notification.notifiable
      return redirect_to review_path(review) if review
    when "topic_membership_request"
      topic = notification.notifiable
      forum = topic&.forum
      return redirect_to forum_topic_topic_members_path(forum, topic) if forum && topic
    end
    # どの分岐にも当てはまらなければ通知一覧へ戻る
    redirect_back fallback_location: notifications_path
  end
end