class Public::PostsController < ApplicationController
  before_action :set_forum_and_topic, only: %i[create destroy edit update]
  before_action :set_post, only: %i[destroy edit update]
  before_action :authenticate_user!, only: %i[create destroy edit update]
  before_action :authorize_post_owner!, only: %i[destroy edit update]
  before_action :authorize_posting!, only: %i[create]
  before_action :forbid_guest_user!, only: [:create, :edit, :update, :destroy]

  # POST /forums/:forum_id/topics/:topic_id/posts
  def create
    # ロック済トピックへの投稿は管理者以外不可
    if @topic.locked? && !admin_user?
      respond_with_lock_forbidden and return
    end

    @post = @topic.posts.build(post_params)
    @post.creator_id = current_user.id if @post.respond_to?(:creator_id)

    if @post.save
      @posts = paginated_posts
      respond_to do |format|
        format.js
        format.html { redirect_to forum_topic_path(@forum, @topic), notice: '投稿しました' }
      end
    else
      @posts = paginated_posts
      respond_to do |format|
        format.js   { render status: :unprocessable_entity }
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
      @posts = paginated_posts
      respond_to do |format|
        format.js
        format.html { redirect_to forum_topic_path(@forum, @topic), notice: '投稿を削除しました。' }
      end
    else
      respond_to do |format|
        format.js   { render js: "alert('投稿の削除に失敗しました。');", status: :internal_server_error }
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

  # 投稿の所有者または管理者かどうかを判定
  def authorize_post_owner!
    return if admin_user?
    return if object_belongs_to_current_user?(@post)
    redirect_to forum_topic_path(@forum, @topic), alert: '編集権限がありません。投稿一覧に戻ります。'
  end

  # 投稿する権限の確認（作成・参加者・管理者のみ可）
  def authorize_posting!
    return if admin_user? || object_belongs_to_current_user?(@topic)
    return if topic_approved_member?

    respond_to do |format|
      format.html { redirect_back fallback_location: forum_topic_path(@forum, @topic), alert: '投稿するには参加が必要です。参加申請を送信してください。' }
      format.js   { render js: "alert('投稿するには参加が必要です。');", status: :forbidden }
    end
  end

  # 管理者権限判定
  def admin_user?
    current_user&.respond_to?(:admin?) && current_user.admin?
  end

  # さまざまな命名に対応した所有者判定（creator/user/id等に柔軟対応）
  def object_belongs_to_current_user?(obj)
    return true  if obj.respond_to?(:creator)   && obj.creator   == current_user
    return true  if obj.respond_to?(:creator_id) && obj.creator_id == current_user&.id
    return true  if obj.respond_to?(:user)      && obj.user      == current_user
    return true  if obj.respond_to?(:user_id)   && obj.user_id   == current_user&.id
    false
  end

  # topicに承認済メンバーとして現在のユーザーが含まれるか
  def topic_approved_member?
    @topic.respond_to?(:topic_memberships) &&
      @topic.topic_memberships.approved.exists?(user_id: current_user.id)
  end

  # 投稿一覧（ページネーション、gem有無による分岐も吸収）
  def paginated_posts
    posts = @topic.posts.order(created_at: :asc)
    if defined?(Kaminari)
      posts.page(params[:page])
    elsif defined?(WillPaginate)
      posts.paginate(page: params[:page])
    else
      posts
    end
  end

  # JS/HTML両方で使う「ロックされた投稿ブロック」の共通レスポンス
  def respond_with_lock_forbidden
    respond_to do |format|
      format.html { redirect_to forum_topic_path(@forum, @topic), alert: 'このトピックはロックされているため投稿できません。' }
      format.js   { render js: "alert('このトピックはロックされているため投稿できません。');", status: :forbidden }
    end
  end
end