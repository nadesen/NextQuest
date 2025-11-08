class Public::TopicsController < ApplicationController
  before_action :set_forum, except: %i[new create]
  before_action :set_topic, only: %i[show edit update destroy]
  before_action :authenticate_user!, only: %i[new create edit update destroy]
  before_action :prevent_guest_posting!, only: %i[new create]
  before_action :authorize_topic_owner!, only: %i[edit update destroy]

  # GET /forums/:forum_id/topics
  def index
    @topics = @forum.topics.order(pinned: :desc, updated_at: :desc)
    @topics = @topics.page(params[:page]) if defined?(Kaminari) || defined?(WillPaginate)
  end

  # GET /forums/:forum_id/topics/:id
  def show
    @posts = @topic.posts.order(created_at: :asc)
    @posts = @posts.page(params[:page]) if defined?(Kaminari) || defined?(WillPaginate)
  end

  # GET /topics/new  (全フォーラム共通) または /forums/:forum_id/topics/new
  def new
    # ネストされたルートなら @forum が set_forum により存在するはず。
    if params[:forum_id].present?
      @forum = Forum.find(params[:forum_id])
      @topic = @forum.topics.build
    else
      # トップレベル new: フォーラム選択を表示するため @forums を渡す
      @forums = Forum.order(:position)
      @topic = Topic.new
    end
  end

  # POST /topics  (全フォーラム共通) または /forums/:forum_id/topics
  def create
    # 優先順: ネストされた forum_id -> フォームの topic[:forum_id]
    forum_id = params[:forum_id].presence || topic_params[:forum_id].presence

    if forum_id.present?
      @forum = Forum.find(forum_id)
      @topic = @forum.topics.build(topic_params.except(:forum_id))
    else
      # フォーラム未選択ならエラー
      @forums = Forum.order(:position)
      @topic = Topic.new(topic_params.except(:forum_id))
      flash.now[:alert] = 'フォーラムを選択してください'
      render :new and return
    end

    # 作成者情報をセット（モデルのカラムに合わせて調整してください）
    if @topic.respond_to?(:creator_id)
      @topic.creator_id ||= current_user.id
    elsif @topic.respond_to?(:user_id)
      @topic.user_id ||= current_user.id
    end

    if @topic.save
      redirect_to forum_topic_path(@forum, @topic), notice: 'トピックを作成しました。'
    else
      @forums ||= Forum.order(:position)
      flash.now[:alert] = 'トピックの作成に失敗しました。入力内容を確認してください。'
      render :new
    end
  end

  # GET /forums/:forum_id/topics/:id/edit
  def edit
  end

  # PATCH/PUT /forums/:forum_id/topics/:id
  def update
    if @topic.update(topic_params.except(:forum_id))
      redirect_to forum_topic_path(@forum, @topic), notice: 'トピックを更新しました。'
    else
      flash.now[:alert] = 'トピックの更新に失敗しました。入力内容を確認してください。'
      render :edit
    end
  end

  # DELETE /forums/:forum_id/topics/:id
  def destroy
    @topic.destroy
    redirect_to forum_topics_path(@forum), notice: 'トピックを削除しました。'
  end

  private

  # ネストされたルート用に forum をセット（new/create のときは除外）
  def set_forum
    @forum = Forum.find(params[:forum_id])
  end

  # set_topic はネストされた場合とトップレベルの両方に対応
  def set_topic
    if params[:forum_id].present?
      @forum = Forum.find(params[:forum_id])
      @topic = @forum.topics.find(params[:id])
    else
      @topic = Topic.find(params[:id])
      @forum = @topic.forum
    end
  end

  # :forum_id を許可（トップレベル new から選択された forum_id を受け取るため）
  def topic_params
    params.require(:topic).permit(:forum_id, :title, :description, :pinned, :locked)
  end

  def prevent_guest_posting!
    return unless current_user && current_user.respond_to?(:guest?) && current_user.guest?

    # ネストされていない場合はフォーラム一覧へ。ネストありならそのフォーラムのトピック一覧へ。
    redirect_target = @forum.present? ? forum_topics_path(@forum) : forums_path
    redirect_to redirect_target, alert: 'ゲストユーザーは投稿できません。'
  end

  def authorize_topic_owner!
    return if current_user&.admin?
    return if @topic.respond_to?(:creator_id) && @topic.creator_id == current_user&.id
    return if @topic.respond_to?(:user) && @topic.user == current_user

    redirect_to forum_topics_path(@forum), alert: 'この操作を行う権限がありません。'
  end
end
