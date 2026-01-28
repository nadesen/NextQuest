class Public::TopicMembersController < ApplicationController
  before_action :set_forum_and_topic
  before_action :authenticate_user!
  before_action :ensure_owner_or_admin!

  # 定数：許可ステータス
  ALLOWED_STATUSES = %w[approved rejected].freeze

  # GET /forums/:forum_id/topics/:topic_id/members
  def index
    @pending_memberships = @topic.topic_memberships.pending.includes(:user)
    @approved_memberships = @topic.topic_memberships.approved.includes(:user)
  end

  # PATCH /forums/:forum_id/topics/:topic_id/members/:id
  # params[:status] expected 'approved' or 'rejected'
  def update
    tm = @topic.topic_memberships.find(params[:id])
    new_status = params[:status].to_s

    unless ALLOWED_STATUSES.include?(new_status)
      redirect_back fallback_location: forum_topic_topic_members_path(@forum, @topic), alert: '無効なステータスです。' and return
    end

    tm.status = new_status
    tm.approved_by = current_user if new_status == 'approved'

    if tm.save
      send_status_notification!(tm, new_status)
      notice = new_status == 'approved' ? '参加を承認しました。' : '参加を拒否しました。'
      redirect_back fallback_location: forum_topic_topic_members_path(@forum, @topic), notice: notice
    else
      redirect_back fallback_location: forum_topic_topic_members_path(@forum, @topic), alert: '操作に失敗しました。'
    end
  end

  private

  def set_forum_and_topic
    @forum = Forum.find(params[:forum_id])
    @topic = @forum.topics.find(params[:topic_id])
  end

  # 管理者またはトピックの所有者のみ許可
  def ensure_owner_or_admin!
    return if admin_user?
    return if topic_owner?

    redirect_to forum_topic_path(@forum, @topic), alert: 'このページを表示する権限がありません。'
  end

  # 管理者権限チェック
  def admin_user?
    current_user.respond_to?(:admin?) && current_user.admin?
  end

  # トピックの所有者権限チェック（creator_id/creator両対応）
  def topic_owner?
    (@topic.respond_to?(:creator_id) && @topic.creator_id == current_user&.id) ||
      (@topic.respond_to?(:creator)   && @topic.creator == current_user)
  end

  # 通知作成（承認/拒否の時のみ）
  def send_status_notification!(topic_membership, status)
    notif_type =
      case status
      when 'approved' then 'topic_membership_approved'
      when 'rejected' then 'topic_membership_rejected'
      end
    if notif_type
      Notification.create!(
        user: topic_membership.user,
        notifiable: topic_membership,
        notif_type: notif_type
      )
    end
  end
end