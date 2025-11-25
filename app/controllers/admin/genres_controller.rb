class Admin::GenresController < ApplicationController
  before_action :redirect_non_admin_to_public_root
  before_action :set_genre, only: [:edit, :update, :destroy]

  def index
    @genres = Genre.order(id: :asc).page(params[:page]).per(20)
  end

  def new
    @genre = Genre.new
  end

  def create
    @genre = Genre.new(genre_params)
    if @genre.save
      redirect_to admin_genres_path, notice: 'ジャンルを作成しました。'
    else
      render :new
    end
  end

  def edit; end

  def update
    if @genre.update(genre_params)
      redirect_to admin_genres_path, notice: 'ジャンルを更新しました。'
    else
      render :edit
    end
  end

  def destroy
    @genre.destroy
    redirect_to admin_genres_path, notice: 'ジャンルを削除しました。'
  end

  private

  def redirect_non_admin_to_public_root
    unless current_admin
      redirect_to root_path and return
    end
  end

  def set_genre
    @genre = Genre.find(params[:id])
  end

  def genre_params
    params.require(:genre).permit(:name)
  end
end