class Public::FollowsController < ApplicationController
  before_action :authenticate_user!

  # POST /users/:id/follow
  def create
    user = find_user
    if user && current_user != user
      current_user.follow(user)
      # 必要ならフラッシュを付ける: flash[:notice] = "#{user.nickname || user.name} をフォローしました"
    end
    redirect_back fallback_location: user_path(user)
  end

  # DELETE /users/:id/unfollow
  def destroy
    user = find_user
    if user && current_user != user
      current_user.unfollow(user)
      # 必要ならフラッシュを付ける: flash[:notice] = "#{user.nickname || user.name} のフォローを解除しました"
    end
    redirect_back fallback_location: user_path(user)
  end

  # GET /users/:id/followings
  def followings
    @user  = find_user
    @users = @user.followings
  end

  # GET /users/:id/followers
  def followers
    @user  = find_user
    @users = @user.followers
  end

  private

  # ユーザー取得を共通化
  def find_user
    User.find(params[:id])
  end
end