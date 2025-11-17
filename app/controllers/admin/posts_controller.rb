class Admin::PostsController < ApplicationController
  before_action :authenticate_admin!
  before_action :set_post, only: [:show, :update, :destroy]

  def index
    @posts = Post.includes(:topic, :creator).order(created_at: :desc)
    # ページネーションが必要なら .page(params[:page]).per(20) を追加
  end

  def show
    # @post は set_post で取得済み
  end

  def update
    if @post.update(post_params)
      redirect_to admin_post_path(@post), notice: '投稿を更新しました。'
    else
      render :show
    end
  end

  def destroy
    topic = @post.topic
    @post.destroy
    # トピック詳細画面から削除していることが想定されるのでトピック詳細に戻す
    if topic.present?
      redirect_to admin_topic_path(topic), notice: '投稿を削除しました。'
    else
      redirect_to admin_posts_path, notice: '投稿を削除しました。'
    end
  end

  private

  def set_post
    @post = Post.find(params[:id])
  end

  def post_params
    # 管理画面で更新可能にしたい属性を許可
    params.require(:post).permit(:content, :edited)
  end
end

