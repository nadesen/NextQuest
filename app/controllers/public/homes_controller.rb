# 公開用ホームページコントローラー
#
# 機能:
#   - サイトのトップページ（ランディングページ）を表示
#   - 最新のトピックとレビューを表示してユーザーの興味を引く
#
# 認証:
#   - 認証不要（未ログインユーザーもアクセス可能）
#
# トップページの役割:
#   - サイトの入り口として、最新コンテンツを紹介
#   - ユーザーの回遊を促進
class Public::HomesController < ApplicationController
  # 定数定義
  # トップページに表示する最新コンテンツの件数
  LATEST_TOPICS_LIMIT = 5
  LATEST_REVIEWS_LIMIT = 5

  # GET /
  # トップページ表示
  #
  # 機能:
  #   - 最新のトピック一覧を表示（最大5件）
  #   - 最新のレビュー一覧を表示（最大5件）
  #
  # インスタンス変数:
  #   @latest_topics - 最新トピック一覧（作成日時の降順）
  #   @latest_reviews - 最新レビュー一覧（作成日時の降順）
  #
  # パフォーマンス最適化:
  #   - 必要に応じて includes で N+1 問題対策を追加可能
  def top
    # 最新のトピック一覧を取得（作成日時の降順、最大5件）
    @latest_topics = fetch_latest_topics

    # 最新のレビュー一覧を取得（作成日時の降順、最大5件）
    @latest_reviews = fetch_latest_reviews
  end

  private

  # 最新トピック一覧を取得
  #
  # 作成日時の降順で並び替え、指定件数のみ取得
  # N+1 問題対策として、必要に応じて関連データを事前読み込み
  #
  # @return [ActiveRecord::Relation] 最新トピック一覧
  #
  # 備考:
  #   - ビューで creator や forum を表示する場合は includes を追加
  #   - 例: Topic.includes(:creator, :forum).order(...)
  def fetch_latest_topics
    Topic.order(created_at: :desc).limit(LATEST_TOPICS_LIMIT)
  end

  # 最新レビュー一覧を取得
  #
  # 作成日時の降順で並び替え、指定件数のみ取得
  # N+1 問題対策として、必要に応じて関連データを事前読み込み
  #
  # @return [ActiveRecord::Relation] 最新レビュー一覧
  #
  # 備考:
  #   - ビューで user や platform, genre を表示する場合は includes を追加
  #   - 例: Review.includes(:user, :platform, :genre).order(...)
  def fetch_latest_reviews
    Review.order(created_at: :desc).limit(LATEST_REVIEWS_LIMIT)
  end
end