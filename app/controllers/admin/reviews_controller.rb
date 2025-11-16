class Admin::ReviewsController < ApplicationController
  before_action :authenticate_admin!
  before_action :set_review, only: [:show, :destroy]

  def index
    @reviews = Review.includes(:user, :platform, :genre).order(created_at: :desc).limit(200)
  end

  def show; end

  def destroy
    @review.destroy
    redirect_to admin_reviews_path, notice: 'レビューを削除しました。'
  end

  private

  def set_review
    @review = Review.find(params[:id])
  end
end