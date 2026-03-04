# 公開用いいね（Like）機能コントローラー
#
# 機能:
#   - レビューへのいいね作成
#   - レビューへのいいね削除
#   - ログインユーザーのみアクセス可能
#
# 認証:
#   - authenticate_user! でログインユーザーをチェック
#   - 未ログインの場合はログインページへリダイレクト
#
# いいね機能の設計:
#   - ポリモーフィック関連（likeable_id/likeable_type）を使用
#   - 現在はレビューのみ対応
#   - Ajax でボタンの部分置き換えを想定（replace_btn ビュー）
#   - カウンターキャッシュ（likes_count）を使用してパフォーマンス最適化
class Public::LikesController < ApplicationController
  # before_action フィルター
  # 認証チェック: いいね機能はログインユーザーのみ
  before_action :authenticate_user!, only: %i[create destroy]

  # レビュー取得: 作成・削除時に使用
  before_action :set_review, only: %i[create destroy]

  # POST /reviews/:id/likes
  # レビューにいいねを追加
  #
  # 処理フロー:
  #   1. 既にいいね済みかチェック（find_or_initialize_by）
  #   2. 新規の場合のみ保存
  #   3. レビューを再読み込みして最新の likes_count を取得
  #   4. Ajax でいいねボタンを部分置き換え
  #
  # レスポンス:
  #   - 成功時: replace_btn ビューを返す（Ajax 用）
  #   - 失敗時: 422 Unprocessable Entity
  #
  # 冪等性:
  #   - 既にいいね済みの場合でも正常にボタンを返す（エラーにしない）
  def create
    # 既にいいね済みかチェック（find_or_initialize_by で冪等性を確保）
    @like = find_or_initialize_like

    if @like.new_record?
      # 新規いいねの場合: 保存処理
      if @like.save
        # カウンターキャッシュを最新化
        @review.reload
        # Ajax でボタン部分を置き換え
        render 'replace_btn'
      else
        # 保存に失敗した場合（バリデーションエラーなど）
        Rails.logger.error("Like creation failed: #{@like.errors.full_messages.join(', ')}")
        head :unprocessable_entity
      end
    else
      # 既にいいね済みの場合: 再保存せずボタンだけ置き換え
      # （冪等性を保つため、エラーにしない）
      render 'replace_btn'
    end
  end

  # DELETE /reviews/:id/likes
  # レビューからいいねを削除
  #
  # 処理フロー:
  #   1. 現在のユーザーのいいねを検索
  #   2. 存在する場合のみ削除
  #   3. レビューを再読み込みして最新の likes_count を取得
  #   4. Ajax でいいねボタンを部分置き換え
  #
  # レスポンス:
  #   - 成功時: replace_btn ビューを返す（Ajax 用）
  #   - いいねが存在しない場合: 404 Not Found
  #
  # 備考:
  #   - 既に削除済みの場合は 404 を返す（冪等性は不要と判断）
  def destroy
    # 現在のユーザーのいいねを検索
    @like = find_like

    if @like
      # いいねが存在する場合: 削除処理
      @like.destroy

      # カウンターキャッシュを最新化
      @review.reload

      # Ajax でボタン部分を置き換え
      render 'replace_btn'
    else
      # いいねが存在しない場合（既に削除済みなど）
      Rails.logger.warn(
        "Like not found for deletion: " \
        "User ID=#{current_user.id}, " \
        "Review ID=#{@review.id}"
      )
      head :not_found
    end
  end

  private

  # レビューをIDから取得
  #
  # レビューIDはパスに応じて複数の場所に出現する可能性がある:
  #   - params[:id]: /reviews/:id/likes の場合
  #   - params[:review_id]: /reviews/:review_id/likes の場合（ネストルート）
  #
  # ActiveRecord::RecordNotFound が発生した場合は rescue で処理
  # 不正なIDでアクセスされた場合、404 Not Found を返す
  #
  # インスタンス変数:
  #   @review - 取得したレビューオブジェクト
  def set_review
    # パスに応じてレビューIDを取得（柔軟なルーティングに対応）
    review_id = params[:id] || params[:review_id]

    @review = Review.find(review_id)
  rescue ActiveRecord::RecordNotFound
    # レビューが見つからない場合は 404 を返す
    Rails.logger.warn(
      "Review not found: " \
      "ID=#{review_id}, " \
      "IP=#{request.remote_ip}"
    )
    head :not_found
  end

  # いいねを検索または初期化（作成用）
  #
  # find_or_initialize_by を使用して冪等性を確保
  # 既にいいね済みの場合は既存のレコードを返す
  #
  # @return [Like] いいねオブジェクト（永続化済みまたは未保存）
  #
  # 備考:
  #   - likeable_type は自動的に設定される（ポリモーフィック関連）
  #   - 現在は Review のみ対応だが、将来的に他のモデルにも拡張可能
  def find_or_initialize_like
    current_user.likes.find_or_initialize_by(
      likeable_id: @review.id,
      likeable_type: 'Review'
    )
  end

  # いいねを検索（削除用）
  #
  # 現在のユーザーが対象レビューにしたいいねを検索
  #
  # @return [Like, nil] いいねオブジェクト、または nil
  def find_like
    current_user.likes.find_by(
      likeable_id: @review.id,
      likeable_type: 'Review'
    )
  end
end