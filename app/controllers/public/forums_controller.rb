class Public::ForumsController < ApplicationController
  before_action :set_forum,   only: %i[show edit update destroy]
  before_action :authenticate_user!, only: %i[new create edit update destroy index show]
  before_action :require_admin!,     only: %i[new create edit update destroy]

  # GET /forums
  def index
    @forums = Forum.order(position: :asc)
    @forums = paginate(@forums)
  end

  # GET /forums/:id
  def show
    # フォーラム詳細に最近のトピックや統計情報を表示したい場合
    @recent_topics = @forum.topics.order(updated_at: :desc).limit(10)
  end

  # GET /forums/new
  def new
    @forum = Forum.new
  end

  # POST /forums
  def create
    @forum = Forum.new(forum_params)
    @forum.creator_id = current_user.id if @forum.respond_to?(:creator_id)

    if @forum.save
      redirect_to forums_path, notice: 'フォーラムを作成しました。'
    else
      flash.now[:alert] = 'フォーラムの作成に失敗しました。入力内容を確認してください。'
      render :new
    end
  end

  # GET /forums/:id/edit
  def edit; end

  # PATCH/PUT /forums/:id
  def update
    if @forum.update(forum_params)
      redirect_to forums_path, notice: 'フォーラムを更新しました。'
    else
      flash.now[:alert] = 'フォーラムの更新に失敗しました。入力内容を確認してくさい。'
      render :edit
    end
  end

  # DELETE /forums/:id
  def destroy
    @forum.destroy
    redirect_to forums_path, notice: 'フォーラムを削除しました。'
  end

  private

  def set_forum
    @forum = Forum.find(params[:id])
  end

  def forum_params
    params.require(:forum).permit(:title, :description, :public, :position)
  end

  # 管理者以外は全ての管理操作を禁ずる
  def require_admin!
    unless current_user&.admin?
      redirect_to root_path, alert: 'この操作を行う権限がありません。'
    end
  end

  # ページネーション用ヘルパー（Kaminari/WillPaginate 両対応）
  def paginate(scope)
    if defined?(Kaminari)
      scope.page(params[:page])
    elsif defined?(WillPaginate)
      scope.paginate(page: params[:page])
    else
      scope
    end
  end
end