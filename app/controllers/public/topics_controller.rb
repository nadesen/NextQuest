class Public::TopicsController < ApplicationController
  before_action :set_forum, except: %i[new create]
  before_action :set_topic, only: %i[show edit update destroy]
  before_action :require_login, only: %i[new create show edit update destroy]
  before_action :prevent_guest_posting!, only: %i[new create]
  before_action :authorize_topic_owner!, only: %i[edit update destroy]

  # GET /forums/:forum_id/topics
  def index
    # 並び替え対象の確認（不正な値はデフォルトにする）
    sort = %w[title created_at posts_count].include?(params[:sort]) ? params[:sort] : 'created_at'
    direction = params[:direction] == 'asc' ? 'asc' : 'desc'

    # pinned は常に優先してソート（先頭に表示）
    base_scope = @forum.topics.order(pinned: :desc)

    # 並び替え句を組み立てる
    order_clause =
      case sort
      when 'title'
        "title #{direction}"
      when 'created_at'
        "created_at #{direction}"
      when 'posts_count'
        # posts_count を使う想定（counter_cache が設定されていること）
        "posts_count #{direction}"
      else
        "created_at #{direction}"
      end

    @topics = base_scope.order(Arel.sql(order_clause))
    @topics = @topics.page(params[:page]) if defined?(Kaminari) || defined?(WillPaginate)
  end

  # GET /forums/:forum_id/topics/:id
  def show
    @posts = @topic.posts.order(created_at: :asc)
    @posts = @posts.page(params[:page]) if defined?(Kaminari) || defined?(WillPaginate)
    # 非同期投稿用フォームで利用する空の Post を用意
    @post = Post.new

    # 投稿権限判定（作成者 / admin / 承認済メンバーのみ投稿可）
    @can_post = false
    if user_signed_in?
      @can_post = true if current_user.respond_to?(:admin?) && current_user.admin?

      # 作成者判定：関連オブジェクトで比較できればそれを使い、無ければ creator_id / user_id で比較する
      creator = @topic.respond_to?(:creator) ? @topic.creator : @topic.user
      if creator.present?
        @can_post = true if creator == current_user
      else
        @can_post = true if @topic.respond_to?(:creator_id) && @topic.creator_id == current_user&.id
        @can_post = true if @topic.respond_to?(:user_id) && @topic.user_id == current_user&.id
      end

      # 承認済メンバーかどうか（作成者や admin でなければチェック）
      if !@can_post && @topic.respond_to?(:topic_memberships)
        @can_post = @topic.topic_memberships.approved.exists?(user_id: current_user.id)
      end
    end
  end

  # GET /topics/new  (全フォーラム共通) または /forums/:forum_id/topics/new
  def new
    @forums = Forum.order(:position)
    if params[:forum_id].present?
      @forum = Forum.find(params[:forum_id])
      @topic = @forum.topics.build
    else
      @topic = Topic.new
    end
  end

  def create
    forum_id = params[:forum_id].presence || topic_params[:forum_id].presence

    if forum_id.present?
      @forum = Forum.find(forum_id)
      @topic = @forum.topics.build(topic_params.except(:forum_id))
    else
      # フォーラム未選択なら topic_params をそのまま使ってモデル検証させる
      @forums = Forum.order(:position)
      @topic = Topic.new(topic_params.except(:forum_id))
      # モデル側の validates :forum_id があるので valid? を呼んでエラーを収集する
      @topic.valid?
      # ここでは追加で errors.add をしない（モデルの message を利用する）
      render :new and return
    end

    # 作成者情報をセット
    if @topic.respond_to?(:creator_id)
      @topic.creator_id ||= current_user.id
    elsif @topic.respond_to?(:user_id)
      @topic.user_id ||= current_user.id
    end

    if @topic.save
      redirect_to forum_topic_path(@forum, @topic), notice: 'コミュニティを作成しました。'
    else
      @forums ||= Forum.order(:position)
      flash.now[:alert] = 'コミュニティの作成に失敗しました。入力内容を確認してください。'
      render :new
    end
  end

  # GET /forums/:forum_id/topics/:id/edit
  def edit
    # フォーラム選択肢が必要なので必ず用意する
    @forums = Forum.order(:position)
  end

  # PATCH/PUT /forums/:forum_id/topics/:id
  def update
    # edit を再描画する場合のために準備
    @forums = Forum.order(:position)

    tp = topic_params.dup
    new_forum_id = tp.delete(:forum_id)

    if @topic.update(tp)
      if new_forum_id.present? && new_forum_id.to_i != @forum.id
        if @topic.update(forum_id: new_forum_id)
          redirect_to forum_topic_path(@topic.forum, @topic), notice: 'コミュニティを更新しました。' and return
        else
          flash.now[:alert] = 'フォーラムの移動に失敗しました。'
          render :edit and return
        end
      end

      redirect_to forum_topic_path(@forum, @topic), notice: 'コミュニティを更新しました.'
    else
      flash.now[:alert] = 'コミュニティの更新に失敗しました。入力内容を確認してください。'
      render :edit
    end
  end

  # DELETE /forums/:forum_id/topics/:id
  def destroy
    @topic.destroy
    # 削除後はマイページ（現在のユーザーの show）へ遷移
    if user_signed_in?
      redirect_to user_path(current_user), notice: 'コミュニティを削除しました。'
    else
      # 万一ログインしていなければフォーラムのトピック一覧へフォールバック
      redirect_to forum_topics_path(@forum), notice: 'コミュニテを削除しました。'
    end
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
    return if current_user&.respond_to?(:admin?) && current_user.admin?
    return if @topic.respond_to?(:creator_id) && @topic.creator_id == current_user&.id
    return if @topic.respond_to?(:user) && @topic.user == current_user

    redirect_to forum_topics_path(@forum), alert: 'この操作を行う権限がありません。'
  end
end
