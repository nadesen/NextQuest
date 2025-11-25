class Admin::ReviewCommentsController < ApplicationController
  before_action :authenticate_admin!
  def destroy
    ReviewComment.find(params[:id]).destroy
    redirect_back fallback_location: admin_reviews_path, notice: "コメントを削除しました。"
  end
end