class Admin::TopicsController < ApplicationController
  before_action :redirect_non_admin_to_public_root
  before_action :set_topic, only: [:show, :update, :destroy]

  def index
    # 並び替えパラメータ取得
    permitted_sorts = %w[id title creator_id posts_count created_at]
    sort = permitted_sorts.include?(params[:sort]) ? params[:sort] : "id"
    direction = params[:direction].present? ? (params[:direction] == 'asc' ? 'asc' : 'desc') : 'asc'
  
    # 通常の検索 ＆ 並び替え
    @topics = Topic.includes(:forum, :creator).order("#{sort} #{direction}")
  
    # フォーラムで絞り込みがある場合
    if params[:forum_id].present?
      @forum = Forum.find_by(id: params[:forum_id])
      @topics = @topics.where(forum_id: @forum.id) if @forum
    end
  
    @topics = @topics.page(params[:page]).per(20)
  end

  def show
    # トピック本体
    # @topic は before_action/set_topic で読み込み済み
    # 関連する投稿を取得（作成順）
    @posts = @topic.posts.order(created_at: :asc).page(params[:page]).per(20)
  end

  def update
    if @topic.update(topic_params)
      redirect_to admin_topic_path(@topic), notice: 'トピックを更新しました。'
    else
      @posts = @topic.posts.order(created_at: :asc)
      render :show
    end
  end

  def destroy
    @topic.destroy
    redirect_to admin_topics_path, notice: 'トピックを削除しました。'
  end

  private

  def redirect_non_admin_to_public_root
    unless current_admin
      redirect_to root_path and return
    end
  end

  def set_topic
    @topic = Topic.find(params[:id])
  end

  def topic_params
    params.require(:topic).permit(:title, :description, :locked)
  end
end