# 公開用レビューコメント管理コントローラー
#
# 機能:
#   - レビューへのコメント作成
#   - レビューコメントの削除
#   - ログインユーザーのみアクセス可能
#   - ゲストユーザーは利用不可
#
# 認証・認可:
#   - authenticate_user! でログインユーザーをチェック
#   - forbid_guest_user! でゲストユーザーを除外
#   - 承認済みレビューのみコメント可能（管理者は例外）
#   - 削除は自分のコメントまたは管理者のみ
#
# コメントのスコア:
#   - Language.get_data でコメント内容の感情分析スコアを自動取得
class Public::ReviewCommentsController < ApplicationController
  # 定数定義
  # ゲストユーザーのメールアドレス
  GUEST_USER_EMAIL = 'guest@example.com'

  # フラッシュメッセージ
  FLASH_MESSAGES = {
    created: 'コメントを投稿しました。',
    destroyed: 'コメントを削除しました。',
    unapproved_review: '承認されていないレビューにはコメントできません。',
    unauthorized_delete: '削除権限がありません。',
    guest_user_forbidden: 'ゲストユーザーはコメント機能を利用できません。',
    review_not_found: 'レビューが見つかりませんでした。',
    comment_not_found: 'コメントが見つかりませんでした。'
  }.freeze

  # before_action フィルター
  # 認証チェック: 全アクションでログイン必須
  before_action :authenticate_user!

  # ゲストユーザーチェック: ゲストユーザーはコメント機能を利用不可
  before_action :forbid_guest_user!, only: %i[create destroy]

  # レビュー取得と権限チェック: コメント作成時
  before_action :set_and_authorize_review!, only: %i[create]

  # コメント取得と権限チェック: コメント削除時
  before_action :set_and_authorize_comment!, only: %i[destroy]

  # POST /reviews/:review_id/review_comments
  # レビューにコメントを作成
  #
  # 処理フロー:
  #   1. レビューの承認状態をチェック（管理者以外は承認済みレビューのみ）
  #   2. コメントを作成
  #   3. 感情分析スコアを自動設定（Language.get_data）
  #   4. 成功/失敗に応じてレスポンス
  #
  # レスポンス:
  #   - 成功時: JS（Ajax）または HTML でリダイレクト
  #   - 失敗時: エラーメッセージを表示
  #
  # 備考:
  #   - Ajax 対応（format.js）
  #   - コメント一覧を作成日時の昇順で取得
  def create
    # コメントを作成
    @comment = build_comment

    if @comment.save
      # 成功時: コメント一覧を更新
      @review_comments = fetch_ordered_comments(@review)

      respond_to do |format|
        format.js
        format.html { redirect_to review_path(@review), notice: FLASH_MESSAGES[:created] }
      end
    else
      # 失敗時: エラーメッセージを表示
      handle_create_failure
    end
  end

  # DELETE /review_comments/:id
  # レビューコメントを削除
  #
  # 処理フロー:
  #   1. 削除権限をチェック（自分のコメントまたは管理者）
  #   2. 権限がある場合のみ削除
  #   3. レスポンス
  #
  # レスポンス:
  #   - 成功時: JS（Ajax）または HTML でリダイレクト
  #   - 権限エラー時: エラーメッセージを表示
  #
  # 備考:
  #   - Ajax 対応（format.js）
  #   - コメント一覧を作成日時の昇順で取得
  def destroy
    # 削除権限チェックは set_and_authorize_comment! で実施済み

    if @comment.destroy
      # 成功時: コメント一覧を更新
      @review_comments = fetch_ordered_comments(@review)

      respond_to do |format|
        format.js
        format.html { redirect_to review_path(@review), notice: FLASH_MESSAGES[:destroyed] }
      end
    else
      # 削除失敗時（外部キー制約やコールバックによる失敗など）
      handle_destroy_failure
    end
  end

  private

  # ゲストユーザーのアクセスを禁止
  #
  # ゲストユーザーはコメント機能を利用できないため、
  # ルートページへリダイレクトして警告メッセージを表示
  def forbid_guest_user!
    if current_user&.email == GUEST_USER_EMAIL
      redirect_to root_path, alert: FLASH_MESSAGES[:guest_user_forbidden]
    end
  end

  # レビューを取得して権限チェック
  #
  # 未承認レビューには管理者以外コメント不可
  #
  # インスタンス変数:
  #   @review - 取得したレビューオブジェクト
  #
  # 権限チェック:
  #   - 承認済みレビュー: 全ユーザーがコメント可能
  #   - 未承認レビュー: 管理者のみコメント可能
  def set_and_authorize_review!
    @review = Review.find(params[:review_id])

    # 未承認レビューへのコメントは管理者以外禁止
    unless review_commentable?(@review)
      respond_with_unapproved_review_error
    end
  rescue ActiveRecord::RecordNotFound
    handle_review_not_found
  end

  # コメントを取得して権限チェック
  #
  # 削除権限があるのは:
  #   - コメントの所有者
  #   - 管理者
  #
  # インスタンス変数:
  #   @comment - 取得したコメントオブジェクト
  #   @review - コメントが属するレビュー
  #
  # 権限チェック:
  #   - 所有者または管理者のみ削除可能
  def set_and_authorize_comment!
    @comment = ReviewComment.find(params[:id])
    @review = @comment.review

    # 削除権限チェック
    unless comment_deletable?(@comment)
      respond_with_unauthorized_delete_error
    end
  rescue ActiveRecord::RecordNotFound
    handle_comment_not_found
  end

  # レビューにコメント可能か判定
  #
  # 承認済みレビューまたは管理者の場合は true
  #
  # @param review [Review] 判定対象のレビュー
  # @return [Boolean] コメント可能な場合 true、それ以外 false
  def review_commentable?(review)
    review.approved? || admin_user?
  end

  # コメントを削除可能か判定
  #
  # コメントの所有者または管理者の場合は true
  #
  # @param comment [ReviewComment] 判定対象のコメント
  # @return [Boolean] 削除可能な場合 true、それ以外 false
  def comment_deletable?(comment)
    owns_comment?(comment) || admin_user?
  end

  # コメントを作成
  #
  # 現在のユーザーに紐づくコメントを作成
  # 感情分析スコアを自動設定
  #
  # @return [ReviewComment] 作成されたコメントオブジェクト（未保存）
  #
  # 備考:
  #   - Language.get_data で感情分析スコアを取得
  #   - score が nil の場合は 0.0 をデフォルト値として設定
  def build_comment
    comment = current_user.review_comments.new(review_comment_params)
    comment.review = @review

    # 感情分���スコアを取得（Language.get_data が nil を返す場合に備える）
    comment.score = fetch_sentiment_score(comment.comment)

    comment
  end

  # 感情分析スコアを取得
  #
  # Language.get_data を使用してコメント内容の感情分析を実行
  #
  # @param text [String] 分析対象のテキスト
  # @return [Float] 感情分析スコア（エラー時は 0.0）
  #
  # 備考:
  #   - Language.get_data が例外を発生させる場合に備えてrescue
  def fetch_sentiment_score(text)
    Language.get_data(text) || 0.0
  rescue StandardError => e
    # 感情分析APIのエラーをログに記録
    Rails.logger.error(
      "Sentiment analysis failed: " \
      "Error=#{e.message}, " \
      "User ID=#{current_user.id}"
    )
    0.0 # デフォルト値を返す
  end

  # コメント一覧を取得（並び順を統一）
  #
  # レビューに紐づくコメントを作成日時の昇順で取得
  #
  # @param review [Review] 対象のレビュー
  # @return [ActiveRecord::Relation] コメント一覧（作成日時の昇順）
  def fetch_ordered_comments(review)
    review.review_comments.order(created_at: :asc)
  end

  # 管理者ユーザーか判定
  #
  # @return [Boolean] 管理者の場合 true、それ以外 false
  def admin_user?
    current_user&.respond_to?(:admin?) && current_user.admin?
  end

  # コメントの所有者か判定
  #
  # @param comment [ReviewComment] 判定対象のコメント
  # @return [Boolean] 所有者の場合 true、それ以外 false
  def owns_comment?(comment)
    comment.user == current_user
  end

  # ストロングパラメータ
  #
  # 許可するパラメータ:
  #   - comment: コメント内容
  def review_comment_params
    params.require(:review_comment).permit(:comment)
  end

  # 未承認レビューへのコメントエラー
  #
  # JS/HTML 両方に対応した共通レスポンス
  def respond_with_unapproved_review_error
    respond_to do |format|
      format.html do
        redirect_to review_path(@review), alert: FLASH_MESSAGES[:unapproved_review]
      end
      format.js do
        render js: "alert('#{FLASH_MESSAGES[:unapproved_review]}');", status: :forbidden
      end
    end
  end

  # 削除権限エラー
  #
  # JS/HTML 両方に対応した共通レスポンス
  def respond_with_unauthorized_delete_error
    @review_comments = fetch_ordered_comments(@review)

    respond_to do |format|
      format.html do
        redirect_to review_path(@review), alert: FLASH_MESSAGES[:unauthorized_delete]
      end
      format.js do
        flash.now[:alert] = FLASH_MESSAGES[:unauthorized_delete]
        render :destroy
      end
    end
  end

  # コメント作成失敗時の処理
  #
  # エラーメッセージを表示
  def handle_create_failure
    @review_comments = fetch_ordered_comments(@review)

    respond_to do |format|
      format.js { render :create, status: :unprocessable_entity }
      format.html do
        error_message = @comment.errors.full_messages.join(', ')
        redirect_to review_path(@review), alert: error_message
      end
    end
  end

  # コメント削除失敗時の処理
  #
  # エラーメッセージを表示
  def handle_destroy_failure
    @review_comments = fetch_ordered_comments(@review)

    respond_to do |format|
      format.js do
        render js: "alert('コメントの削除に失敗しました。');", status: :internal_server_error
      end
      format.html do
        error_message = @comment.errors.full_messages.join(', ')
        redirect_to review_path(@review), alert: "削除できませんでした: #{error_message}"
      end
    end
  end

  # レビューが見つからない場合の処理
  def handle_review_not_found
    Rails.logger.warn(
      "Review not found: " \
      "ID=#{params[:review_id]}, " \
      "IP=#{request.remote_ip}"
    )

    respond_to do |format|
      format.html { redirect_to root_path, alert: FLASH_MESSAGES[:review_not_found] }
      format.js { render js: "alert('#{FLASH_MESSAGES[:review_not_found]}');", status: :not_found }
    end
  end

  # コメントが見つからない場合の処理
  def handle_comment_not_found
    Rails.logger.warn(
      "Comment not found: " \
      "ID=#{params[:id]}, " \
      "IP=#{request.remote_ip}"
    )

    respond_to do |format|
      format.html { redirect_to root_path, alert: FLASH_MESSAGES[:comment_not_found] }
      format.js { render js: "alert('#{FLASH_MESSAGES[:comment_not_found]}');", status: :not_found }
    end
  end
end