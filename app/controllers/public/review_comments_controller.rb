class  Public::ReviewCommentsController < ApplicationController
  before_action :authenticate_user!
  before_action :forbid_guest_user!, only: [:create, :destroy]

  def create
    @review = Review.find(params[:review_id])
    @comment = current_user.review_comments.new(review_comment_params)
    @comment.review = @review
    @comment.score = Language.get_data(@comment.comment)

    if @comment.save
      respond_to do |format|
        format.js   # create.js.erb を返す（成功時）
        format.html { redirect_to review_path(@review), notice: 'コメントを投稿しました' }
      end
    else
      respond_to do |format|
        # 失敗時も create.js.erb をレンダリングする（JS 側で @comment.errors を処理するため）
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
