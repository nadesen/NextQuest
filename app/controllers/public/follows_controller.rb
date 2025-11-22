class Public::FollowsController < ApplicationController
  before_action :authenticate_user!

  # POST /users/:id/follow
  def create
    user = User.find(params[:id])
    if user && current_user != user
      current_user.follow(user)
      # 必要ならフラッシュを付ける: flash[:notice] = "#{user.nickname || user.name} をフォローしました"
    end
    redirect_back fallback_location: user_path(user)
  end

  # DELETE /users/:id/unfollow
  def destroy
    user = User.find(params[:id])
    if user && current_user != user
      current_user.unfollow(user)
      # 必要ならフラッシュを付ける: flash[:notice] = "#{user.nickname || user.name} のフォローを解除しました"
    end
    redirect_back fallback_location: user_path(user)
  end

  # GET /users/:id/followings
  def followings
    user = User.find(params[:id])
    @users = user.followings
  end

  # GET /users/:id/followers
  def followers
    user = User.find(params[:id])
    @users = user.followers
  end
end
