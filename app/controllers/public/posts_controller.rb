class Public::PostsController < ApplicationController
  before_action :set_forum_and_topic, only: %i[create destroy edit update]
  before_action :set_post, only: %i[destroy edit update]
  before_action :require_login, only: %i[create destroy edit update]
  before_action :authorize_post_owner!, only: %i[destroy edit update]
  before_action :authorize_posting!, only: %i[create]
  before_action :forbid_guest_user!, only: [:create, :edit, :update, :destroy]

  # POST /forums/:forum_id/topics/:topic_id/posts
  def create
    # topicロック確認
    if @topic.locked? && !(current_user&.respond_to?(:admin?) && current_user.admin?)
      respond_to do |format|
        format.html {
          redirect_to forum_topic_path(@forum, @topic), alert: 'このトピックはロックされているため投稿できません。'
        }
        format.js {
          render js: "alert('このトピックはロックされているため投稿できません。');", status: :forbidden
        }
      end
      return
    end

    @post = @topic.posts.build(post_params)
    @post.creator_id = current_user.id if @post.respond_to?(:creator_id)

    if @post.save
      # 最新の投稿一覧を用意して JS で差し替える
      @posts = @topic.posts.order(created_at: :asc)
      @posts = @posts.page(params[:page]) if defined?(Kaminari) || defined?(WillPaginate)
      respond_to do |format|
        format.js
        format.html { redirect_to forum_topic_path(@forum, @topic), notice: '投稿しました' }
      end
    else
      @posts = @topic.posts.order(created_at: :asc)
      @posts = @posts.page(params[:page]) if defined?(Kaminari) || defined?(WillPaginate)
      respond_to do |format|
        format.js { render status: :unprocessable_entity }
        format.html do
          flash.now[:alert] = '投稿に失敗しました'
          render 'public/topics/show'
        end
      end
    end
  end

  # DELETE /forums/:forum_id/topics/:topic_id/posts/:id
  def destroy
    if @post.destroy
      @posts = @topic.posts.order(created_at: :asc)
      @posts = @posts.page(params[:page]) if defined?(Kaminari) || defined?(WillPaginate)
      respond_to do |format|
        format.js
        format.html { redirect_to forum_topic_path(@forum, @topic), notice: '投稿を削除しました。' }
      end
    else
      # destroy が false を返す場合に備える
      respond_to do |format|
        format.js { render js: "alert('投稿の削除に失敗しました。');", status: :internal_server_error }
        format.html { redirect_to forum_topic_path(@forum, @topic), alert: '投稿の削除に失敗しました。' }
      end
    end
  end

  private

  def set_forum_and_topic
    @forum = Forum.find(params[:forum_id])
    @topic = @forum.topics.find(params[:topic_id])
  end

  def set_post
    @post = @topic.posts.find(params[:id])
  end

  def post_params
    params.require(:post).permit(:content)
  end

  # 投稿の所有者（creator_id あるいは user association）かどうかを判定
  def authorize_post_owner!
    # 管理者は常に許可
    return if current_user.respond_to?(:admin?) && current_user.admin?

    # creator オブジェクトと比較できる場合
    if @post.respond_to?(:creator) && @post.creator.present?
      return if @post.creator == current_user
    end

    # creator_id で比較できる場合（数値フィールド）
    if @post.respond_to?(:creator_id)
      return if @post.creator_id == current_user&.id
    end

    # 古い実装や別名 user を使っている場合
    if @post.respond_to?(:user) && @post.user.present?
      return if @post.user == current_user
    end

    if @post.respond_to?(:user_id)
      return if @post.user_id == current_user&.id
    end

    # どれにも該当しない場合はアクセス拒否（リダイレクトで通知）
    redirect_to forum_topic_path(@forum, @topic), alert: '編集権限がありません。投稿一覧に戻ります。'
  end

  # 投稿権限の確認（create 前のガード）
  def authorize_posting!
    return if current_user.respond_to?(:admin?) && current_user.admin?

    # 作成者判定：関連オブジェクトで比較できればそれを使い、無ければ creator_id / user_id で比較する
    creator = @topic.respond_to?(:creator) ? @topic.creator : @topic.user
    if creator.present?
      return if creator == current_user
    else
      return if @topic.respond_to?(:creator_id) && @topic.creator_id == current_user&.id
      return if @topic.respond_to?(:user_id) && @topic.user_id == current_user&.id
    end

    if @topic.respond_to?(:topic_memberships)
      return if @topic.topic_memberships.approved.exists?(user_id: current_user.id)
    end

    respond_to do |format|
      format.html { redirect_back fallback_location: forum_topic_path(@forum, @topic), alert: '投稿するには参加が必要です。参加申請を送信してください。' }
      format.js { render js: "alert('投稿するには参加が必要です。');", status: :forbidden }
    end
  end
end
