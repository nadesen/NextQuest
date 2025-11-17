class Admin::ForumsController < ApplicationController
  before_action :authenticate_admin!
  before_action :set_forum, only: [:edit, :update, :destroy]

  def index
    @forums = Forum.order(position: :asc, created_at: :desc).page(params[:page]).per(20)
  end

  def new
    @forum = Forum.new
  end

  def create
    @forum = Forum.new(forum_params)
    if @forum.save
      redirect_to admin_forums_path, notice: 'フォーラムを作成しました。'
    else
      render :new
    end
  end

  def edit; end

  def update
    if @forum.update(forum_params)
      redirect_to admin_forums_path, notice: 'フォーラムを更新しました。'
    else
      render :edit
    end
  end

  def destroy
    @forum.destroy
    redirect_to admin_forums_path, notice: 'フォーラムを削除しました。'
  end

  private

  def set_forum
    @forum = Forum.find(params[:id])
  end

  def forum_params
    params.require(:forum).permit(:title, :description, :public, :position)
  end
end