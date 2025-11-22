class Public::LikesController < ApplicationController
  before_action :authenticate_user!, only: [:create, :destroy]
  before_action :set_review, only: [:create, :destroy]

  # POST /reviews/:id/likes
  def create
    @like = current_user.likes.find_or_initialize_by(likeable_id: @review.id)

    if @like.new_record?
      if @like.save
        @review.reload   # ← ここで最新の likes_count を読み込む
        render 'replace_btn'
      else
        head :unprocessable_entity
      end
    else
      render 'replace_btn'
    end
  end

  # DELETE /reviews/:id/likes
  def destroy
    @like = current_user.likes.find_by(likeable_id: @review.id)
    if @like
      @like.destroy
      @review.reload   # ← ここで最新の likes_count を読み込む
      render 'replace_btn'
    else
      head :not_found
    end
  end

  private

  def set_review
    review_id = params[:id] || params[:review_id]
    @review = Review.find(review_id)
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end
end