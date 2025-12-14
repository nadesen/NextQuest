class  Public::ReviewCommentsController < ApplicationController
  before_action :authenticate_user!
  before_action :forbid_guest_user!, only: [:create, :destroy]

  def create
    @review = Review.find(params[:review_id])
    # 管理者以外で未承認レビューはコメント禁止
    unless @review.approved? || (current_user.respond_to?(:admin?) && current_user.admin?)
      respond_to do |format|
        format.html { redirect_to review_path(@review), alert: "承認されていないレビューにはコメントできません。" }
        format.js { render js: "alert('承認されていないレビューにはコメントできません。');", status: :forbidden }
      end
      return
    end
  
    @comment = current_user.review_comments.new(review_comment_params)
    @comment.review = @review
    @comment.score = Language.get_data(@comment.comment)
  
    if @comment.save
      respond_to do |format|
        format.js
        format.html { redirect_to review_path(@review), notice: 'コメントを投稿しました' }
      end
    else
      respond_to do |format|
        format.js { render :create, status: :unprocessable_entity }
        format.html do
          flash[:alert] = @comment.errors.full_messages.join(', ')
          redirect_to review_path(@review)
        end
      end
    end
  end

  def destroy
    @comment = ReviewComment.find(params[:id])
    @review = @comment.review
    if @comment.user == current_user
      @comment.destroy
    end

    respond_to do |format|
      format.js   # destroy.js.erb を返す
      format.html { redirect_to review_path(@review) }
    end
  end

  private

  def review_comment_params
    params.require(:review_comment).permit(:comment)
  end
end
