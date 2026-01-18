class Public::ReviewsController < ApplicationController
  before_action :authenticate_user!, only: %i[new create show edit update destroy index]
  before_action :set_review, only: %i[show edit update destroy]
  before_action :forbid_guest_user!, only: %i[new create edit update destroy]

  def index
    @platforms = Platform.order(id: :asc)
    @genres    = Genre.order(:name)
    @reviews   = Review.where(approved: true).includes(:platform, :genre, :user)
    @reviews   = filter_reviews(@reviews)
    @reviews   = sort_reviews(@reviews)
    @reviews   = paginate_reviews(@reviews)
  end

  def show
    # 未承認レビューは管理者以外見られない
    unless @review.approved? || admin_access?
      redirect_to reviews_path, alert: "このレビューは管理者により非表示となっています。" and return
    end
    @review_comment = ReviewComment.new
    @review_comments = paginate_review_comments(@review.review_comments)
  end

  def new
    @review = Review.new
    load_selects
  end

  def create
    @review = Review.new(review_params.merge(user_id: current_user.id))
    if @review.save
      redirect_to review_path(@review), notice: 'レビューを作成しました。'
    else
      load_selects
      flash.now[:alert] = 'レビューの作成に失敗しました。入力内容を確認してください。'
      render :new
    end
  end

  def edit
    load_selects
    forbid_edit_unless_owner!
  end

  def update
    load_selects
    forbid_edit_unless_owner! and return
    if @review.update(review_params)
      redirect_to review_path(@review), notice: 'レビューを更新しました。'
    else
      flash.now[:alert] = '更新に失敗しました。入力内容を確認してください。'
      render :edit
    end
  end

  def destroy
    if owner_or_admin?
      @review.destroy
      redirect_to user_path(current_user), notice: 'レビューを削除しました。'
    else
      redirect_to review_path(@review), alert: '削除権限がありません。'
    end
  end

  private

  def set_review
    @review = Review.find(params[:id])
  end

  def review_params
    params.require(:review).permit(:platform_id, :genre_id, :title, :play_time, :rating, :content)
  end

  def load_selects
    @platforms = Platform.order(id: :asc)
    @genres    = Genre.order(:name)
  end

  def filter_reviews(reviews)
    reviews = reviews.where(platform_id: params[:platform_id]) if params[:platform_id].present?
    reviews = reviews.where(genre_id: params[:genre_id])       if params[:genre_id].present?
    reviews
  end

  def sort_reviews(reviews)
    permitted_sorts = %w[created_at title likes_count]
    sort      = permitted_sorts.include?(params[:sort]) ? params[:sort] : "created_at"
    direction = params[:direction] == 'asc' ? 'asc' : 'desc'
    if sort == 'likes_count'
      reviews.left_joins(:likes).group("reviews.id").order("COUNT(likes.id) #{direction}")
    else
      reviews.order("#{sort} #{direction}")
    end
  end

  def paginate_reviews(reviews)
    if defined?(Kaminari)
      reviews.page(params[:page]).per(30)
    elsif defined?(WillPaginate)
      reviews.paginate(page: params[:page], per_page: 30)
    else
      reviews
    end
  end

  def paginate_review_comments(review_comments)
    ordered = review_comments.order(created_at: :asc)
    if defined?(Kaminari)
      ordered.page(params[:review_comments_page]).per(200)
    elsif defined?(WillPaginate)
      ordered.paginate(page: params[:review_comments_page], per_page: 200)
    else
      ordered.limit(200)
    end
  end

  def owner_or_admin?
    current_user && (current_user.id == @review.user_id || (current_user.respond_to?(:admin?) && current_user.admin?))
  end

  def admin_access?
    current_user.respond_to?(:admin?) && current_user.admin?
  end

  def forbid_edit_unless_owner!
    unless current_user && current_user.id == @review.user_id
      redirect_to review_path(@review), alert: '権限がありません。'
      true
    end
  end
end