class Public::ReviewCommentsController < ApplicationController
  before_action :authenticate_user!
  before_action :forbid_guest_user!, only: [:create, :destroy]

  # POST /reviews/:review_id/review_comments
  def create
    @review = find_and_authorize_review!
    return if performed?

    @comment = current_user.review_comments.new(review_comment_params)
    @comment.review = @review
    @comment.score = Language.get_data(@comment.comment)
    @review_comments = ordered_comments(@review)

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

  # DELETE /review_comments/:id
  def destroy
    @comment = ReviewComment.find(params[:id])
    @review = @comment.review
    if owns_comment?(@comment)
      @comment.destroy
    else
      # 本来ここでリダイレクト等しても良い
      flash[:alert] = '削除権限がありません。'
    end
    @review_comments = ordered_comments(@review)
    respond_to do |format|
      format.js
      format.html { redirect_to review_path(@review) }
    end
  end

  private

  # レビュー取得＋未承認なら管理者以外は禁止
  def find_and_authorize_review!
    review = Review.find(params[:review_id])
    unless review.approved? || admin_user?
      respond_to do |format|
        format.html { redirect_to review_path(review), alert: "承認されていないレビューにはコメントできません。" }
        format.js   { render js: "alert('承認されていないレビューにはコメントできません。');", status: :forbidden }
      end
      return nil # フィルター内 return
    end
    review
  end

  # コメントリスト取得（並び順も共通化）
  def ordered_comments(review)
    review.review_comments.order(created_at: :asc)
  end

  # 管理者ユーザーか判定
  def admin_user?
    current_user.respond_to?(:admin?) && current_user.admin?
  end

  # コメントの所有者か？
  def owns_comment?(comment)
    comment.user == current_user
  end

  def review_comment_params
    params.require(:review_comment).permit(:comment)
  end
end