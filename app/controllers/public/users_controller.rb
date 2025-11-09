class Public::UsersController < ApplicationController
  has_many :reviews, dependent: :destroy

  def show
    @user = User.find(params[:id])
    @quests = @user.quests.page(params[:page]).per(6)
  end

  
end
