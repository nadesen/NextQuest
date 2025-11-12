class Public::PostsController < ApplicationController
  before_action :set_forum_and_topic, only: %i[create destroy edit update]
  before_action :set_post, only: %i[destroy edit update]
  # create/destroy/edit/update を保護
  before_action :require_login, only: %i[create destroy edit update]
  before_action :authorize_post_owner!, only: %i[destroy edit update]

  def create
    @post = @topic.posts.build(post_params)
    @post.creator_id = current_user.id if @post.respond_to?(:creator_id)
    if @post.save
      redirect_to forum_topic_path(@forum, @topic), notice: '投稿しました'
    else
      @posts = @topic.posts.order(created_at: :asc).page(params[:page]) if defined?(Kaminari)
      flash.now[:alert] = '投稿に失敗しました'
      render 'public/topics/show'
    end
  end

  # DELETE /forums/:forum_id/topics/:topic_id/posts/:id
  def destroy
    @post.destroy
    redirect_to forum_topic_path(@forum, @topic), notice: '投稿を削除しました。'
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
    # Post モデルのカラム名に合わせて許可するパラメータを調整してください
    params.require(:post).permit(:content)
  end

  def authorize_post_owner!
    # 投稿の所有者（creator_id あるいは user association）かどうかを判定
    return if @post.respond_to?(:creator_id) && @post.creator_id == current_user&.id
    return if @post.respond_to?(:user) && @post.user == current_user

    # 非所有者の場合は "投稿一覧"（そのトピックのページ）へリダイレクト
    redirect_to forum_topic_path(@forum, @topic), alert: '編集権限がありません。投稿一覧に戻ります。'
  end
end
