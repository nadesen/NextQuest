# 管理者用レビューコメント管理コントローラー
#
# 機能:
#   - レビューコメントの削除
#   - 管理者のみアクセス可能
#
# 認証:
#   - authenticate_admin! で管理者権限をチェック
#   - 非管理者は ApplicationController でリダイレクト処理
#
# レビューコメントとは:
#   - ユーザーが投稿したレビューに対するコメント
#   - 不適切なコメントを削除する管理機能
#
# 設計方針:
#   - 現在は削除機能のみ実装
#   - 必要に応じて一覧表示や編集機能を追加可能
class Admin::ReviewCommentsController < ApplicationController
  # フラッシュメッセージ
  FLASH_MESSAGES = {
    destroyed: 'コメントを削除しました。',
    not_found: 'コメントが見つかりませんでした。',
    destroy_failed: 'コメントの削除に失敗しました。'
  }.freeze

  # before_action フィルター
  before_action :authenticate_admin!
  before_action :set_review_comment, only: %i[destroy]

  # DELETE /admin/review_comments/:id
  # レビューコメントを削除
  #
  # リダイレクト先:
  #   - redirect_back で削除前のページに戻る
  #   - フォールバック先: レビュー一覧ページ
  #
  # ユースケース:
  #   - レビュー詳細画面からコメントを削除
  #   - コメント一覧画面から削除
  #   - 削除後は元のページに戻ることでスムーズな管理が可能
  def destroy
    if @review_comment.destroy
      # 削除成功時: 元のページに戻る
      redirect_back(
        fallback_location: admin_reviews_path,
        notice: FLASH_MESSAGES[:destroyed]
      )
    else
      # 削除失敗時: エラーメッセージを表示して元のページに戻る
      # （外部キー制約やコールバックによる失敗など）
      redirect_back(
        fallback_location: admin_reviews_path,
        alert: "#{FLASH_MESSAGES[:destroy_failed]}: #{@review_comment.errors.full_messages.join(', ')}"
      )
    end
  end

  private

  # レビューコメントをIDから取得
  #
  # ActiveRecord::RecordNotFound が発生した場合は rescue で処理
  # 不正なIDでアクセスされた場合、レビュー一覧ページへリダイレクト
  #
  # インスタンス変数:
  #   @review_comment - 取得したレビューコメントオブジェクト
  def set_review_comment
    @review_comment = ReviewComment.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_reviews_path, alert: FLASH_MESSAGES[:not_found]
  end
end