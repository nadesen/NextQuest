class Admin::ReviewsController < ApplicationController
  before_action :redirect_non_admin_to_public_root
  before_action :set_review, only: [:show, :edit, :update, :destroy]
  before_action :load_collections, only: [:edit, :update]

  def index
    permitted_sorts = %w[id title user_id]
    sort = permitted_sorts.include?(params[:sort]) ? params[:sort] : "id"
    direction = params[:direction].present? ? (params[:direction] == 'asc' ? 'asc' : 'desc') : 'asc'
  
    # フィルタ用の選択肢
    @platforms = Platform.order(:name)
    @genres = Genre.order(:name)
  
    @reviews = Review.includes(:user, :platform, :genre)
  
    # 絞り込み条件（プラットフォーム）
    if params[:platform_id].present?
      @reviews = @reviews.where(platform_id: params[:platform_id])
    end
    # 絞り込み条件（ジャンル）
    if params[:genre_id].present?
      @reviews = @reviews.where(genre_id: params[:genre_id])
    end
  
    @reviews = @reviews.order("#{sort} #{direction}").page(params[:page]).per(20)
  end

  def show; end

  def edit
  end

  def update
    if @review.update(review_params)
      redirect_to admin_review_path(@review), notice: 'レビューを更新しました。'
    else
      # load_collections は before_action で呼ばれているので view 用のデータは揃っています
      render :edit
    end
  end

  def destroy
    @review.destroy
    redirect_to admin_reviews_path, notice: 'レビューを削除しました。'
  end

  private

  def redirect_non_admin_to_public_root
    unless current_admin
      redirect_to root_path and return
    end
  end

  def set_review
    @review = Review.find(params[:id])
  end

  def load_collections
    @platforms = Platform.order(:name)
    @genres = Genre.order(:name)
  end

  def review_params
    # 管理画面から編集可能にする属性（approved を必ず許可）
    params.require(:review).permit(:title, :content, :rating, :play_time, :platform_id, :genre_id, :approved)
  end
end