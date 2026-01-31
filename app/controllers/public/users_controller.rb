class Public::UsersController < ApplicationController
  before_action :authenticate_user!, only: [:show, :edit, :update, :destroy, :my_page, :my_likes, :likes]
  before_action :set_user, only: [:show, :edit, :update, :destroy, :likes]
  before_action :authorize_user!, only: [:edit, :update, :destroy]
  before_action :ensure_guest_user_edit_block, only: [:edit]
  before_action :redirect_guest_user_from_mypage, only: [:show]

  def show
    # 各一覧はページネーションを使用（表示上限 5）
    @topics         = paginated(fetch_user_topics(@user.id),          :topics_page)
    @posts          = paginated(fetch_user_posts(@user.id),           :posts_page)
    @reviews        = paginated(fetch_user_reviews(@user.id),         :reviews_page)
    @review_comments = paginated(fetch_user_review_comments(@user),   :review_comments_page)
  end

  # GET /users/:id/likes
  # そのユーザーがいいねしたレビュー一覧を表示
  def likes
    # @user は set_user で取得済み
    @liked_reviews = Review.joins("INNER JOIN likes ON likes.likeable_id = reviews.id")
                           .where(likes: { user_id: @user.id })
                           .includes(:platform, :genre)
                           .order('likes.created_at DESC')
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
    if current_user && current_user.id == @user.id
      sign_out(current_user) if defined?(sign_out)
      if @user.destroy
        redirect_to new_user_registration_path, notice: 'アカウントを削除しました。ご利用ありがとうございました。'
      else
        redirect_to user_path(@user), alert: 'アカウントの削除に失敗しました。'
      end
    else
      redirect_to user_path(@user), alert: '削除権限がありません。'
    end
  end

  private

  # Userを取得
  def set_user
    @user = User.find(params[:id])
  end

  # ページネーション共通化（Kaminari/WillPaginate両対応/デフォ5件）
  def paginated(relation, page_param, per: 5)
    if defined?(Kaminari)
      relation.page(params[page_param]).per(per)
    elsif defined?(WillPaginate)
      relation.paginate(page: params[page_param], per_page: per)
    else
      relation.limit(per)
    end
  end

  # トピックをユーザIDから取得 (AR::Relation で返す)
  def fetch_user_topics(user_id)
    topic_assoc(@user) || Topic.where(author_column_hash(Topic, user_id)).includes(:forum).order(created_at: :desc)
  rescue => e
    Rails.logger.warn("[UsersController#fetch_user_topics] #{e.message}")
    Topic.none
  end

  # ポストをユーザIDから取得
  def fetch_user_posts(user_id)
    post_assoc(@user) || Post.where(author_column_hash(Post, user_id)).includes(:topic).order(created_at: :desc)
  rescue => e
    Rails.logger.warn("[UsersController#fetch_user_posts] #{e.message}")
    Post.none
  end

  # レビューをユーザIDから取得
  def fetch_user_reviews(user_id)
    review_assoc(@user) || Review.where(author_column_hash(Review, user_id)).includes(:platform, :genre).order(created_at: :desc)
  rescue => e
    Rails.logger.warn("[UsersController#fetch_user_reviews] #{e.message}")
    Review.none
  end

  # レビューコメント取得
  def fetch_user_review_comments(user)
    user.review_comments.joins(:review)
        .includes(:review)
        .order(created_at: :desc)
  end

  # モデルごとのユーザー関連カラム判定
  def author_column_hash(model, user_id)
    cols = model.column_names rescue []
    if cols.include?('user_id')      then { user_id: user_id }
    elsif cols.include?('author_id') then { author_id: user_id }
    elsif cols.include?('creator_id') then { creator_id: user_id }
    else {}
    end
  end

  # アソシエーションで取れる場合はそれを優先（Topic/User, Post/User, Review/User）
  def topic_assoc(user)
    user.topics.includes(:forum).order(created_at: :desc) if user.respond_to?(:topics)
  end
  def post_assoc(user)
    user.posts.includes(:topic).order(created_at: :desc) if user.respond_to?(:posts)
  end
  def review_assoc(user)
    user.reviews.includes(:platform, :genre).order(created_at: :desc) if user.respond_to?(:reviews)
  end

  # 編集・削除等の本人確認
  def authorize_user!
    unless current_user && current_user.id == @user.id
      redirect_to(user_signed_in? ? user_path(current_user) : user_path(@user), alert: '編集権限がありません。マイページに移動しました。')
    end
  end

  # ゲストユーザーによる編集ブロック
  def ensure_guest_user_edit_block
    if @user.email == "guest@example.com"
      redirect_to user_path(current_user), notice: "ゲストユーザーはプロフィール編集画面へ遷移できません。"
    end
  end

  # ゲストによるマイページアクセス制限
  def redirect_guest_user_from_mypage
    if user_signed_in? && current_user.email == "guest@example.com" && params[:id].to_i == current_user.id
      redirect_to root_path, alert: "ゲストユーザーはマイページは利用できません。"
    end
  end

  def user_params
    params.require(:user).permit(:name, :nickname, :email, :profile_text)
  end
end