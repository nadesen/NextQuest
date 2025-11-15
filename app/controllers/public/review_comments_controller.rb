class  Public::ReviewCommentsController < ApplicationController
  before_action :authenticate_user!

  def create
    @review = Review.find(params[:review_id])
    @comment = current_user.review_comments.new(review_comment_params)
    @comment.review = @review

    if @comment.save
      respond_to do |format|
        format.js   # create.js.erb を返す
        format.html { redirect_to review_path(@review), notice: 'コメントを投稿しました' }
      end
    else
      respond_to do |format|
        format.js { render status: :unprocessable_entity } # create.js.erb 側でエラー処理可
        format.html { redirect_to review_path(@review), alert: 'コメントを投稿できませんでした' }
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
