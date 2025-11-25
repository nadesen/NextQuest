class Admin::UsersController < ApplicationController
  before_action :redirect_non_admin_to_public_root
  before_action :set_user, only: [:show, :edit, :update, :destroy]

  def index
    @users = User.order(id: :asc).page(params[:page]).per(20)
  end

  def show; end
  def edit; end

  def update
    if @user.update(user_params)
      redirect_to admin_user_path(@user), notice: 'ユーザー情報を更新しました。'
    else
      render :edit
    end
  end

  def destroy
    @user.destroy
    redirect_to admin_users_path, notice: 'ユーザーを削除しました。'
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def redirect_non_admin_to_public_root
    unless current_admin
      redirect_to root_path and return
    end
  end

  def user_params
    params.require(:user).permit(:name, :nickname, :email, :suspended, :profile_text)
  end
end