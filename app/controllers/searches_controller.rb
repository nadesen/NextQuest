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

    case @model
    when 'user'
      # User.search_for を実装済みならそのまま呼ぶ
      @users = User.search_for(@content, @method)
    when 'topic'
      @topics = Topic.search_for(@content, @method)
    when 'review'
      @reviews = Review.search_for(@content, @method)
    when 'all'
      # 全対象検索（必要なら）
      @users   = User.search_for(@content, @method)
      @topics  = Topic.search_for(@content, @method)
      @reviews = Review.search_for(@content, @method)
    else
      # 不正な model パラメータは空の結果でフォールバック
      Rails.logger.info("[SearchesController] unknown model param: #{@model.inspect}")
    end

    # ここで index ビューに渡す（あなたが作成した index.html.erb を使う）
    # 必要ならページネーションのために .page(params[:page]) を追加してください
    render :index
  end
end
