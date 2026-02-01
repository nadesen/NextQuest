Rails.application.routes.draw do
  # =========== 共通 ===========
  root to: 'public/homes#top'
  get '/search', to: 'searches#search', as: :search

  # =========== devise認証関連 ===========
  # ユーザー
  devise_for :users, skip: [:passwords], controllers: {
    registrations: "public/registrations",
    sessions: 'public/sessions'
  }
  # ゲストログイン
  devise_scope :user do
    post "users/guest_sign_in", to: "public/sessions#guest_sign_in"
  end

  # 管理者
  devise_for :admin, skip: [:registrations, :passwords], controllers: {
    sessions: "admin/sessions"
  }

  # =========== ユーザー側の公開アプリ ===========
  scope module: :public do

    # タグ/通知など単体リソース
    resources :tags, only: [:show]
    resources :notifications, only: [:index, :update]

    # ユーザー/プロフィール関連
    resources :users, only: [:index, :show, :edit, :update, :destroy] do
      # フォロー・フォロワー・いいねなどマイページ系
      member do
        get   :followings, to: 'follows#followings'
        get   :followers,  to: 'follows#followers'
        post  :follow,     to: 'follows#create'
        delete :unfollow,  to: 'follows#destroy'
        get   :likes
        get   :reviews,    to: 'reviews#user_reviews'
      end
    end

    # プラットフォーム・ジャンル
    resources :platforms, only: [:index, :show]
    resources :genres,    only: [:index, :show]

    # フォロー一覧と解除
    resources :follows, only: [:index, :destroy]

    # いいね（多態性、レビュー/投稿/その他リソース対応）
    resources :likes, only: [:create, :destroy]

    # レビュー本体/コメント/いいね
    resources :reviews do
      collection do
        post :preview
      end

      resources :review_comments, only: [:create, :destroy]

      # reviewに付随：いいね、いいねしたユーザー一覧
      member do
        post   'likes', to: 'likes#create'
        delete 'likes', to: 'likes#destroy'
      end
    end

    # トピック単発作成
    resources :topics, only: [:new, :create]

    # =========== フォーラム/トピック/投稿（多段ネスト） ===========
    resources :forums, only: [:index, :show] do
      resources :topics, only: [:index, :show, :new, :create, :edit, :update, :destroy] do
        resources :posts, only: [:index, :create, :edit, :update, :destroy]

        # 参加申請・キャンセル・追放
        resources :topic_memberships, only: [:create, :destroy]

        # 管理メンバー一覧・承認
        resources :topic_members, only: [:index, :update], path: 'members', controller: 'topic_members'
      end
    end
  end

  # =========== 管理者用 ===========
  namespace :admin do
    root to: 'homes#top'

    resources :users, only: [:index, :show, :edit, :update, :destroy]
    resources :platforms, only: [:index, :new, :create, :edit, :update, :destroy]
    resources :genres,    only: [:index, :new, :create, :edit, :update, :destroy]
    resources :forums,    only: [:index, :new, :create, :edit, :update, :destroy]
    resources :topics, only: [:index, :show, :update, :destroy] do
      resources :members, only: [:index, :update, :destroy], controller: 'topic_members'
    end
    resources :posts, only: [:index, :show, :update, :destroy]
    resources :actions, only: [:create] # admin actions / audit log
    resources :reviews, only: [:index, :show, :edit, :update, :destroy]
    resources :review_comments, only: [:destroy]
  end

  # =========== 通知（バッチ更新API） ===========
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