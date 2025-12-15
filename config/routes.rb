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
  # ゲストログイン用
  devise_scope :user do
    post "users/guest_sign_in", to: "public/sessions#guest_sign_in"
  end
  
  # ユーザー側のルーティング設定
  scope module: :public do    
    resources :tags, only: [:show]
    resources :notifications, only: [:index, :update]

    # ユーザーとプロフィール関連
    resources :users, only: [:index, :show, :edit, :update, :destroy] do
      member do
        get :followings, to: 'follows#followings'
        get :followers, to: 'follows#followers'
        post :follow, to: 'follows#create'       # POST /users/:id/follow
        delete :unfollow, to: 'follows#destroy' # DELETE /users/:id/unfollow
        
        get :likes
        get :reviews, to: 'reviews#user_reviews' # /users/:id/reviews
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

      # review に付随するいいね（create/destroy）と、いいねしたユーザー一覧(index）を受ける
      member do
        post 'likes', to: 'likes#create'    # /reviews/:review_id/likes (POST)
        delete 'likes', to: 'likes#destroy' # /reviews/:review_id/likes (DELETE) - favorites のパターンに合わせる
      end
    end

    # トピック作成フォーム
    resources :topics, only: [:new, :create]

    # フォーラム / トピック / 投稿
    resources :forums, only: [:index, :show] do
      resources :topics, only: [:index, :show, :new, :create, :edit, :update, :destroy] do
        resources :posts, only: [:index, :create, :edit, :update, :destroy]

        # ユーザーが申請（create）／申請取消（destroy: 自分の申請を取消 or owner が削除/追放）
        resources :topic_memberships, only: [:create, :destroy]

        # 作成者・管理者用のメンバー一覧と承認（members#index, members#update）
        resources :topic_members, only: [:index, :update], path: 'members', controller: 'topic_members'
      end
    end
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
    resources :forums, only: [:index, :new, :create, :edit, :update, :destroy]
    resources :topics, only: [:index, :show, :update, :destroy] do
      resources :members, only: [:index, :update, :destroy], controller: 'topic_members'
    end
    resources :posts, only: [:index, :show, :update, :destroy]
    resources :actions, only: [:create] # admin actions / audit log
    resources :reviews, only: [:index, :show, :edit, :update, :destroy]
    resources :review_comments, only: [:destroy]
  end

  namespace :public do
    resources :notifications, only: [:index, :update] do
      patch :batch_update, on: :collection
    end
  end

  # ActionCable
  mount ActionCable.server => '/cable'

  # Active Storage (Rails mounts these automatically in Rails >= 5.2)
  # direct_uploads and blobs are available by default
   
end
