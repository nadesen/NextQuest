class Public::TopicMembershipsController < ApplicationController
  before_action :set_forum_and_topic
  before_action :authenticate_user!
  before_action :forbid_guest_user!, only: [:create, :destroy]

  # POST /forums/:forum_id/topics/:topic_id/topic_memberships
  def create
    existing_membership = @topic.topic_memberships.find_by(user_id: current_user.id)

    # 拒否されていれば再申請可、それ以外はダブり防止
    if existing_membership.present?
      if existing_membership.status == "rejected"
        existing_membership.destroy
      else
        redirect_back fallback_location: forum_topic_path(@forum, @topic), alert: "既に申請または参加しています。" and return
      end
    end

    new_membership = @topic.topic_memberships.build(user: current_user, status: 'pending')
    if new_membership.save
      redirect_back fallback_location: forum_topic_path(@forum, @topic), notice: '参加申請を送信しました。'
    else
      redirect_back fallback_location: forum_topic_path(@forum, @topic), alert: '参加申請に失敗しました。'
    end
  end

  # DELETE /forums/:forum_id/topics/:topic_id/topic_memberships/:id
  # - ユーザー自身の申請取消・退会、またはトピック作成者/管理者による強制退会
  def destroy
    membership = @topic.topic_memberships.find_by(id: params[:id])
    unless membership
      redirect_back fallback_location: forum_topic_path(@forum, @topic), alert: '該当のメンバー情報が見つかりません。' and return
    end

    # 削除権限: 本人 or トピック所有者 or 管理者
    if deletable_by_current_user?(membership)
      membership.destroy
      redirect_back fallback_location: forum_topic_path(@forum, @topic), notice: 'メンバー情報を削除しました。'
    else
      redirect_back fallback_location: forum_topic_path(@forum, @topic), alert: '操作権限がありません。'
    end
  end

  private

  def set_forum_and_topic
    @forum = Forum.find(params[:forum_id])
    @topic = @forum.topics.find(params[:topic_id])
  end

  # トピック所有者または管理者かどうか判定
  def owner_or_admin?
    return false unless current_user
    return true if admin_user?
    return true if topic_owner?
    false
  end

  def admin_user?
    current_user.respond_to?(:admin?) && current_user.admin?
  end

  def topic_owner?
    (@topic.respond_to?(:creator_id) && @topic.creator_id == current_user.id) ||
      (@topic.respond_to?(:creator) && @topic.creator == current_user)
  end

  # 削除権限チェック: 本人、またはトピック管理者（owner/admin）
  def deletable_by_current_user?(membership)
    membership.user_id == current_user.id || owner_or_admin?
  end
end