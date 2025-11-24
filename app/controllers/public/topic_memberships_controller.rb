class Public::TopicMembershipsController < ApplicationController
  before_action :set_forum_and_topic
  before_action :require_login

  # POST /forums/:forum_id/topics/:topic_id/topic_memberships
  def create
    # 既に申請や参加している場合は重複しないようにする
    tm = @topic.topic_memberships.find_by(user_id: current_user.id)
    if tm.present?
      redirect_back fallback_location: forum_topic_path(@forum, @topic), alert: '既に申請または参加しています。' and return
    end

    tm = @topic.topic_memberships.build(user: current_user, status: 'pending')
    if tm.save
      redirect_back fallback_location: forum_topic_path(@forum, @topic), notice: '参加申請を送信しました。'
    else
      redirect_back fallback_location: forum_topic_path(@forum, @topic), alert: '参加申請に失敗しました。'
    end
  end

  # DELETE /forums/:forum_id/topics/:topic_id/topic_memberships/:id
  # - ユーザーが自分の申請をキャンセル、もしくは承認後の退会、
  # - 作成者/管理者がメンバーを追放する目的でも使える
  def destroy
    tm = @topic.topic_memberships.find(params[:id])
    unless tm
      redirect_back fallback_location: forum_topic_path(@forum, @topic), alert: '該当のメンバー情報が見つかりません。' and return
    end

    # 自分の申請/参加を削除する、あるいは権限のあるユーザー（作成者/admin）が削除する
    if tm.user_id == current_user.id || owner_or_admin?
      tm.destroy
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

  def owner_or_admin?
    return false unless current_user
    return true if current_user.respond_to?(:admin?) && current_user.admin?
    return true if @topic.respond_to?(:creator_id) && @topic.creator_id == current_user.id
    return true if @topic.respond_to?(:creator) && @topic.creator == current_user
    false
  end
end
