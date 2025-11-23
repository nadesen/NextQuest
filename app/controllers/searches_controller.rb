class SearchesController < ApplicationController
  # ログイン必須を外す
  before_action :authenticate_user!

  def search
    # フォームからのパラメータ
    @model   = params[:model]   # 'user' / 'topic' / 'review' を期待
    @content = params[:content]
    @method  = params[:method]  # 'perfect' / 'forward' / 'backward' / 'partial'

    # 初期化（ビューが常に @users/@topics/@reviews を参照できるようにする）
    @users  = []
    @topics = []
    @reviews = []

    topic_sort = %w[title created_at posts_count].include?(params[:topic_sort]) ? params[:topic_sort] : "created_at"
    topic_direction = params[:topic_direction] == 'asc' ? 'asc' : 'desc'
  
    review_sort = %w[created_at title likes_count].include?(params[:review_sort]) ? params[:review_sort] : "created_at"
    review_direction = params[:review_direction] == 'asc' ? 'asc' : 'desc'
  
    case @model
    when 'user'
      @users = User.search_for(@content, @method)
    when 'topic'
      @topics = Topic.search_for(@content, @method)
                 .order("#{topic_sort} #{topic_direction}")
    when 'review'
      if review_sort == 'likes_count'
        @reviews = Review.search_for(@content, @method)
                    .left_joins(:likes)
                    .group("reviews.id")
                    .order("COUNT(likes.id) #{review_direction}")
      else
        @reviews = Review.search_for(@content, @method)
                    .order("#{review_sort} #{review_direction}")
      end
    when 'all'
      @users = User.search_for(@content, @method)
      @topics = Topic.search_for(@content, @method)
                 .order("#{topic_sort} #{topic_direction}")
      if review_sort == 'likes_count'
        @reviews = Review.search_for(@content, @method)
                    .left_joins(:likes)
                    .group("reviews.id")
                    .order("COUNT(likes.id) #{review_direction}")
      else
        @reviews = Review.search_for(@content, @method)
                    .order("#{review_sort} #{review_direction}")
      end
    else
      Rails.logger.info("[SearchesController] unknown model param: #{@model.inspect}")
    end
  
    render :index
  end
end
