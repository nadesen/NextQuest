class Public::TopicMembersController < ApplicationController
  before_action :set_forum_and_topic
  before_action :require_login
  before_action :ensure_owner_or_admin!

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

    unless %w[approved rejected].include?(new_status)
      redirect_back fallback_location: forum_topic_topic_members_path(@forum, @topic), alert: '無効なステータスです。' and return
    end

    tm.status = new_status
    tm.approved_by = current_user if new_status == 'approved'
    if tm.save
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

  def ensure_owner_or_admin!
    return if current_user.respond_to?(:admin?) && current_user.admin?
    return if @topic.respond_to?(:creator_id) && @topic.creator_id == current_user&.id
    return if @topic.respond_to?(:creator) && @topic.creator == current_user

    redirect_to forum_topic_path(@forum, @topic), alert: 'このページを表示する権限がありません。'
  end
end