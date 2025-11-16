class Admin::PlatformsController < ApplicationController
  before_action :authenticate_admin!
  before_action :set_platform, only: [:edit, :update, :destroy]

  def index
    @platforms = Platform.order(:name)
  end

  def new
    @platform = Platform.new
  end

  def create
    @platform = Platform.new(platform_params)
    if @platform.save
      redirect_to admin_platforms_path, notice: 'プラットフォームを作成しました。'
    else
      render :new
    end
  end

  def edit; end

  def update
    if @platform.update(platform_params)
      redirect_to admin_platforms_path, notice: 'プラットフォームを更新しました。'
    else
      render :edit
    end
  end

  def destroy
    @platform.destroy
    redirect_to admin_platforms_path, notice: 'プラットフォームを削除しました。'
  end

  private

  def set_platform
    @platform = Platform.find(params[:id])
  end

  def platform_params
    params.require(:platform).permit(:name)
  end
end