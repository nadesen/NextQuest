class Admin::TopicMembersController < ApplicationController
  before_action :authenticate_admin!
  before_action :set_topic

  # GET /admin/topics/:topic_id/members
  def index
    @pending_memberships = @topic.topic_memberships.pending.includes(:user)
    @approved_memberships = @topic.topic_memberships.approved.includes(:user)
  end

  # PATCH /admin/topics/:topic_id/members/:id
  # params[:status] expected 'approved' or 'rejected'
  def update
    tm = @topic.topic_memberships.find(params[:id])
    new_status = params[:status].to_s

    unless %w[approved rejected].include?(new_status)
      redirect_back fallback_location: admin_topic_members_path(@topic), alert: '無効なステータスです。' and return
    end

    tm.status = new_status

    if tm.save
      notice = new_status == 'approved' ? '参加を承認しました。' : '参加を拒否しました。'
      redirect_back fallback_location: admin_topic_members_path(@topic), notice: notice
    else
      redirect_back fallback_location: admin_topic_members_path(@topic), alert: '操作に失敗しました。'
    end
  end

  # DELETE /admin/topics/:topic_id/members/:id
  def destroy
    tm = @topic.topic_memberships.find(params[:id])
    tm.destroy
    redirect_back fallback_location: admin_topic_members_path(@topic), notice: 'メンバー情報を削除しました。'
  end

  private

  def set_topic
    @topic = Topic.find(params[:topic_id])
  end
end