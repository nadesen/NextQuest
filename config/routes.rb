Rails.application.routes.draw do
  # 共通
  root to: 'public/homes#top'
  get '/search', to: 'searches#search', as: :search

  # ユーザー用
  # URL /customers/sign_in ...
  devise_for :users,skip: [:passwords], controllers: {
    registrations: "public/registrations",
    sessions: 'public/sessions'
  }
  # ユーザー側のルーティング設定
  scope module: :public do    
    resources :tags, only: [:show]

    # ユーザーとプロフィール関連
    resources :users, only: [:index, :show, :edit, :update, :destroy] do
      member do
        get :followings
        get :followers
        get :likes
        get :reviews, to: 'reviews#user_reviews' # /users/:id/reviews
      end
      collection do
        post :guest_sign_in, to: 'users#guest_sign_in' # /users/guest_sign_in
      end
    end

    # プラットフォーム / ジャンル
    resources :platforms, only: [:index, :show]
    resources :genres, only: [:index, :show]

    # フォロー（ユーザー -> プラットフォーム）とユーザー間のフォロー（フォロー コントローラー / モデルによって処理）
    resources :follows, only: [:index, :destroy]

    # いいね（多態性：レビュー/投稿/その他）
    resources :likes, only: [:create, :destroy]

    # レビュー
    resources :reviews do
      collection do
        post :preview
      end

      resources :review_comments, only: [:create, :destroy]
    end

    # トピック作成フォーム
    resources :topics, only: [:new, :create]

    # フォーラム / トピック / 投稿
    resources :forums, only: [:index, :show] do
      resources :topics, only: [:index, :show, :new, :create, :edit, :update, :destroy] do
        resources :posts, only: [:index, :create, :edit, :update, :destroy]
        resources :subscriptions, only: [:create]
      end
    end

    # サブスクリプションの削除パス
    resources :subscriptions, only: [:destroy]
  end

  # 管理者用
  # URL /admin/sign_in ...
  devise_for :admin, skip: [:registrations, :passwords] ,controllers: {
    sessions: "admin/sessions"
  }
  namespace :admin do
    root to: 'homes#top' # GET /admin

    resources :users, only: [:index, :show, :edit, :update, :destroy]
    resources :platforms, only: [:index, :new, :create, :edit, :update, :destroy]
    resources :genres, only: [:index, :new, :create, :edit, :update, :destroy]
    resources :forums, only: [:index, :edit, :update, :destroy]
    resources :topics, only: [:index, :show, :update, :destroy]
    resources :posts, only: [:index, :show, :update, :destroy]
    resources :actions, only: [:create] # admin actions / audit log
    resources :reviews, only: [:index, :show, :update, :destroy]
  end

  # ActionCable
  mount ActionCable.server => '/cable'

  # Active Storage (Rails mounts these automatically in Rails >= 5.2)
  # direct_uploads and blobs are available by default
   
end
