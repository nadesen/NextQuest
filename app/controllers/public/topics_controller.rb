class Public::TopicsController < ApplicationController
  before_action :set_forum, except: %i[new create]
  before_action :set_topic, only: %i[show edit update destroy]
  before_action :authenticate_user!, only: %i[new create show edit update destroy]
  before_action :prevent_guest_posting!, only: %i[new create]
  before_action :authorize_topic_owner!, only: %i[edit update destroy]
  before_action :forbid_guest_user!, only: [:new, :create, :edit, :update, :destroy]

  # GET /forums/:forum_id/topics
  def index
    @topics = filtered_sorted_topics
    @topics = paginate_collection(@topics, 30)
  end

  # GET /forums/:forum_id/topics/:id
  def show
    # 管理者以外はロックされたトピックにアクセス不可
    if @topic.locked? && !admin_user?
      redirect_to forum_topics_path(@forum), alert: 'このトピックは管理者によりロックされているためアクセスできません。'
      return
    end

    @posts = @topic.posts.order(:created_at)
    @posts = paginate_collection(@posts, nil)
    @post = Post.new # 非同期投稿フォーム用

    # 投稿権限判定
    @can_post = can_post_to_topic?
  end

  # GET /topics/new または /forums/:forum_id/topics/new
  def new
    @forums = Forum.order(:position)
    @forum  = Forum.find(params[:forum_id]) if params[:forum_id].present?
    @topic  = @forum ? @forum.topics.build : Topic.new
  end

  def create
    forum_id = params[:forum_id].presence || topic_params[:forum_id].presence

    if forum_id.present?
      @forum = Forum.find(forum_id)
      @topic = @forum.topics.build(topic_params.except(:forum_id))
    else
      @forums = Forum.order(:position)
      @topic  = Topic.new(topic_params.except(:forum_id))
      @topic.valid?
      render :new and return
    end

    set_topic_creator(@topic)

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
    @forums = Forum.order(:position)
  end

  # PATCH/PUT /forums/:forum_id/topics/:id
  def update
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
      redirect_to forum_topics_path(@forum), notice: 'コミュニティを削除しました。'
    end
  end

  private

  # forumをセット（new/create以外）
  def set_forum
    @forum = Forum.find(params[:forum_id])
  end

  # topicセット（フォーラムID有無で場合分け）
  def set_topic
    if params[:forum_id].present?
      @forum  = Forum.find(params[:forum_id])
      @topic  = @forum.topics.find(params[:id])
    else
      @topic  = Topic.find(params[:id])
      @forum  = @topic.forum
    end
  end

  # StrongParameter（forum_idはnew共通フォーム用に許可）
  def topic_params
    params.require(:topic).permit(:forum_id, :title, :description, :pinned, :locked)
  end

  # ゲストユーザーは投稿不可
  def prevent_guest_posting!
    if guest_user?
      redirect_target = @forum.present? ? forum_topics_path(@forum) : forums_path
      redirect_to redirect_target, alert: 'ゲストユーザーは投稿できません。'
    end
  end

  # 権限判定（管理者か投稿者のみ許可）
  def authorize_topic_owner!
    return if admin_user?
    return if @topic.respond_to?(:creator_id) && @topic.creator_id == current_user&.id
    return if @topic.respond_to?(:user) && @topic.user == current_user

    redirect_to forum_topics_path(@forum), alert: 'この操作を行う権限がありません。'
  end

  # 管理者ユーザー判定
  def admin_user?
    current_user&.respond_to?(:admin?) && current_user.admin?
  end

  # ゲストユーザー判定
  def guest_user?
    current_user&.respond_to?(:guest?) && current_user.guest?
  end

  # 投稿権限判定
  def can_post_to_topic?
    return false unless user_signed_in?
    return true  if admin_user?
    creator      = @topic.respond_to?(:creator) ? @topic.creator : @topic.user
    return true  if creator.present? && creator == current_user
    return true  if @topic.respond_to?(:creator_id) && @topic.creator_id == current_user.id
    return true  if @topic.respond_to?(:user_id) && @topic.user_id == current_user.id

    # 承認済みメンバーか
    if @topic.respond_to?(:topic_memberships)
      return @topic.topic_memberships.approved.exists?(user_id: current_user.id)
    end

    false
  end

  # トピック作成時に作成者情報セット
  def set_topic_creator(topic)
    if topic.respond_to?(:creator_id)
      topic.creator_id ||= current_user.id
    elsif topic.respond_to?(:user_id)
      topic.user_id ||= current_user.id
    end
  end

  # 並び替え・絞り込みされたトピック一覧を返す
  def filtered_sorted_topics
    permitted_sorts = %w[title created_at posts_count]
    sort      = permitted_sorts.include?(params[:sort]) ? params[:sort] : 'created_at'
    direction = params[:direction] == 'asc' ? 'asc' : 'desc'
    base_scope = @forum.topics.where(locked: false).order(pinned: :desc)

    order_clause =
      case sort
      when 'title'       then "title #{direction}"
      when 'created_at'  then "created_at #{direction}"
      when 'posts_count' then "posts_count #{direction}" # counter_cache前提
      else                    "created_at #{direction}"
      end

    base_scope.order(Arel.sql(order_clause))
  end

  # コレクションのページング（Kaminari/WillPaginate対応）
  def paginate_collection(collection, per_page)
    if defined?(Kaminari)
      per_page ? collection.page(params[:page]).per(per_page) : collection.page(params[:page])
    elsif defined?(WillPaginate)
      per_page ? collection.paginate(page: params[:page], per_page: per_page) : collection.paginate(page: params[:page])
    else
      collection
    end
  end
end