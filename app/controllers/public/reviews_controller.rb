class Public::ReviewsController < ApplicationController
  # new/create/show/edit/update/destroy を保護
  before_action :require_login, only: %i[new create show edit update destroy]
  before_action :set_review, only: %i[show edit update destroy]
  before_action :forbid_guest_user!, only: %i[new create edit update destroy]

  def index
    permitted_sorts = %w[created_at title likes_count]
    sort = permitted_sorts.include?(params[:sort]) ? params[:sort] : "created_at"
    direction = params[:direction] == 'asc' ? 'asc' : 'desc'
  
    @platforms = Platform.order(id: :asc)
    @genres = Genre.order(:name)
  
    @reviews = Review.includes(:platform, :genre, :user)
    # 絞り込み (プラットフォームID)
    if params[:platform_id].present?
      @reviews = @reviews.where(platform_id: params[:platform_id])
    end
    # 絞り込み (ジャンルID)
    if params[:genre_id].present?
      @reviews = @reviews.where(genre_id: params[:genre_id])
    end
  
    # 並び替え
    if sort == 'likes_count'
      @reviews = @reviews.left_joins(:likes).group("reviews.id").order("COUNT(likes.id) #{direction}")
    else
      @reviews = @reviews.order("#{sort} #{direction}")
    end
  
    @reviews = @reviews.page(params[:page]) if defined?(Kaminari) || defined?(WillPaginate)
  end

  def show
    # @review は set_review でセット
    @review = Review.find(params[:id])
    @review_comment = ReviewComment.new
  end

  def new
    @review = Review.new
    load_selects
  end

  def create
    @review = Review.new(review_params)
    @review.user_id = current_user.id

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
    # 必要なら投稿者チェックを追加（下の destroy と同様）
    unless current_user && current_user.id == @review.user_id
      redirect_to review_path(@review), alert: '編集権限がありません。'
    end
  end

  def update
    load_selects
    unless current_user && current_user.id == @review.user_id
      redirect_to review_path(@review), alert: '更新権限がありません。' and return
    end

    if @review.update(review_params)
      redirect_to review_path(@review), notice: 'レビューを更新しました。'
    else
      flash.now[:alert] = '更新に失敗しました。入力内容を確認してください。'
      render :edit
    end
  end

  def destroy
    # 投稿者または管理者のみ削除できるようにする場合は条件を追加してください
    if current_user && current_user.id == @review.user_id
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
    @platforms = Platform.all.order(id: :asc)
    @genres = Genre.all.order(:name)
  end
end
