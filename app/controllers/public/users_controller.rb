class Public::UsersController < ApplicationController
  before_action :require_login, only: [:edit, :update, :destroy, :my_page]
  before_action :set_user, only: [:show, :edit, :update, :destroy]
  before_action :authorize_user!, only: [:edit, :update, :destroy]

  def show
    @user = User.find(params[:id])
    @topics = fetch_user_topics(@user.id, limit: 20)
    @posts  = fetch_user_posts(@user.id, limit: 20)
    @reviews = fetch_user_reviews(@user.id, limit: 20)
    # joins(:review) によって review が存在するコメントのみを取得します。
    @review_comments = @user.review_comments.joins(:review)
                            .includes(:review)
                            .order(created_at: :desc)
                            .limit(10)
  end

  def edit; end

  def update
    if @user.update(user_params)
      redirect_to user_path(@user), notice: 'アカウント情報を更新しました。'
    else
      flash.now[:alert] = '更新に失敗しました。入力内容を確認してください。'
      render :edit
    end
  end

  def destroy
    user = @user
    if current_user && current_user.id == user.id
      sign_out(current_user) if defined?(sign_out)
      if user.destroy
        redirect_to new_user_registration_path, notice: 'アカウントを削除しました。ご利用ありがとうございました。'
      else
        redirect_to user_path(user), alert: 'アカウントの削除に失敗しました。'
      end
    else
      redirect_to user_path(user), alert: '削除権限がありません。'
    end
  end

  private

  def fetch_user_topics(user_id, limit: 20)
    return Topic.none unless defined?(Topic)
    if @user.respond_to?(:topics)
      @user.topics.includes(:forum).order(created_at: :desc).limit(limit)
    else
      cols = Topic.column_names rescue []
      if cols.include?('user_id')
        Topic.where(user_id: user_id).includes(:forum).order(created_at: :desc).limit(limit)
      elsif cols.include?('creator_id')
        Topic.where(creator_id: user_id).includes(:forum).order(created_at: :desc).limit(limit)
      elsif cols.include?('author_id')
        Topic.where(author_id: user_id).includes(:forum).order(created_at: :desc).limit(limit)
      elsif Topic.reflect_on_association(:posts) && defined?(Post) && (Post.column_names.include?('user_id') rescue false)
        Topic.joins(:posts).where(posts: { user_id: user_id }).distinct.includes(:forum).order('topics.created_at DESC').limit(limit)
      else
        Topic.none
      end
    end
  rescue => e
    Rails.logger.warn("[UsersController#fetch_user_topics] #{e.message}")
    Topic.none
  end

  def fetch_user_posts(user_id, limit: 20)
    return [] unless defined?(Post)
    if @user.respond_to?(:posts)
      @user.posts.includes(:topic).order(created_at: :desc).limit(limit)
    else
      cols = Post.column_names rescue []
      if cols.include?('user_id')
        Post.where(user_id: user_id).includes(:topic).order(created_at: :desc).limit(limit)
      elsif cols.include?('author_id')
        Post.where(author_id: user_id).includes(:topic).order(created_at: :desc).limit(limit)
      elsif cols.include?('creator_id')
        Post.where(creator_id: user_id).includes(:topic).order(created_at: :desc).limit(limit)
      else
        Post.none
      end
    end
  rescue => e
    Rails.logger.warn("[UsersController#fetch_user_posts] #{e.message}")
    Post.none
  end

  def fetch_user_reviews(user_id, limit: 20)
    return [] unless defined?(Review)
    if @user.respond_to?(:reviews)
      @user.reviews.includes(:platform, :genre).order(created_at: :desc).limit(limit)
    else
      cols = Review.column_names rescue []
      if cols.include?('user_id')
        Review.where(user_id: user_id).includes(:platform, :genre).order(created_at: :desc).limit(limit)
      elsif cols.include?('author_id')
        Review.where(author_id: user_id).includes(:platform, :genre).order(created_at: :desc).limit(limit)
      elsif cols.include?('creator_id')
        Review.where(creator_id: user_id).includes(:platform, :genre).order(created_at: :desc).limit(limit)
      else
        Review.none
      end
    end
  rescue => e
    Rails.logger.warn("[UsersController#fetch_user_reviews] #{e.message}")
    Review.none
  end

  def set_user
    @user = User.find(params[:id])
  end

  def authorize_user!
    # current_user が自分のページを編集しようとしているかチェック
    unless current_user && current_user.id == @user.id
      # ログイン済みなら current_user の show ページへ、未ログインなら通常のユーザー詳細へ
      if user_signed_in?
        redirect_to user_path(current_user), alert: '編集権限がありません。マイページに移動しました。'
      else
        redirect_to user_path(@user), alert: '権限がありません。'
      end
    end
  end

  def user_params
    params.require(:user).permit(:name, :nickname, :email, :profile_text)
  end
end
