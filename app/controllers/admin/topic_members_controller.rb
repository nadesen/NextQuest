# 管理者用トピックメンバー管理コントローラー
#
# 機能:
#   - トピックメンバーシップ（参加申請）の一覧表示
#   - 参加申請の承認・拒否
#   - メンバー情報の削除
#   - 管理者のみアクセス可能
#
# 認証:
#   - authenticate_admin! で管理者権限をチェック
#   - 非管理者は公開トップページへリダイレクト
#
# トピックメンバーシップとは:
#   - ユーザーがトピック（限定的なフォーラムスレッド）への参加を申請
#   - ステータス: pending（申請中）、approved（承認済み）、rejected（拒否）
#   - 管理者が参加の可否を判断
class Admin::TopicMembersController < ApplicationController
  # 定数定義
  # 許可されるステータス値（SQL インジェクション対策）
  PERMITTED_STATUSES = %w[approved rejected].freeze

  # ステータスに対応するメッセージ
  STATUS_MESSAGES = {
    'approved' => '参加を承認しました。',
    'rejected' => '参加を拒否しました。'
  }.freeze

  # フラッシュメッセージ
  FLASH_MESSAGES = {
    invalid_status: '無効なステータスです。',
    update_failed: '操作に失敗しました。',
    destroyed: 'メンバー情報を削除しました。',
    destroy_failed: 'メンバー情報の削除に失敗しました。',
    topic_not_found: 'トピックが見つかりませんでした。',
    membership_not_found: 'メンバーシップが見つかりませんでした。'
  }.freeze

  # before_action フィルター
  before_action :authenticate_admin!
  before_action :set_topic
  before_action :set_topic_membership, only: %i[update destroy]

  # GET /admin/topics/:topic_id/members
  # トピックメンバー一覧表示
  #
  # 機能:
  #   - 申請中（pending）と承認済み（approved）のメンバーシップを分けて表示
  #   - 各メンバーシップに紐づくユーザー情報を事前読み込み（N+1 問題対策）
  #
  # インスタンス変数:
  #   @topic - 対象トピック（set_topic で設定済み）
  #   @pending_memberships - 申請中のメンバーシップ一覧
  #   @approved_memberships - 承認済みのメンバーシップ一覧
  def index
    # 申請中のメンバーシップ一覧（ユーザー情報を事前読み込み）
    @pending_memberships = @topic.topic_memberships
                                 .pending
                                 .includes(:user)
                                 .order(created_at: :asc)

    # 承認済みのメンバーシップ一覧（ユーザー情報を事前読み込み）
    @approved_memberships = @topic.topic_memberships
                                  .approved
                                  .includes(:user)
                                  .order(created_at: :asc)
  end

  # PATCH /admin/topics/:topic_id/members/:id
  # メンバーシップのステータスを更新（承認・拒否）
  #
  # パラメータ:
  #   status - 新しいステータス（'approved' または 'rejected'）
  #
  # 処理フロー:
  #   1. ステータスのバリデーション（許可リストで検証）
  #   2. メンバーシップの更新
  #   3. 成功/失敗に応じたリダイレクト
  #
  # リダイレクト先:
  #   - redirect_back で元のページに戻る
  #   - フォールバック先: メンバー一覧ページ
  def update
    # ステータスの検証（許可リストに含まれるか確認）
    new_status = params[:status].to_s

    unless valid_status?(new_status)
      redirect_back(
        fallback_location: admin_topic_members_path(@topic),
        alert: FLASH_MESSAGES[:invalid_status]
      )
      return
    end

    # ステータスを更新
    @topic_membership.status = new_status

    if @topic_membership.save
      # 成功時: ステータスに応じたメッセージを表示
      notice_message = STATUS_MESSAGES[new_status]
      redirect_back(
        fallback_location: admin_topic_members_path(@topic),
        notice: notice_message
      )
    else
      # 失敗時: エラーメッセージを表示
      alert_message = build_error_message(@topic_membership)
      redirect_back(
        fallback_location: admin_topic_members_path(@topic),
        alert: alert_message
      )
    end
  end

  # DELETE /admin/topics/:topic_id/members/:id
  # メンバーシップを削除
  #
  # 用途:
  #   - 承認済みメンバーの削除（追放）
  #   - 申請中のメンバーシップの削除
  #
  # リダイレクト先:
  #   - redirect_back で元のページに戻る
  #   - フォールバック先: メンバー一覧ページ
  def destroy
    if @topic_membership.destroy
      # 削除成功時
      redirect_back(
        fallback_location: admin_topic_members_path(@topic),
        notice: FLASH_MESSAGES[:destroyed]
      )
    else
      # 削除失敗時（外部キー制約やコールバックによる失敗など）
      alert_message = "#{FLASH_MESSAGES[:destroy_failed]}: #{@topic_membership.errors.full_messages.join(', ')}"
      redirect_back(
        fallback_location: admin_topic_members_path(@topic),
        alert: alert_message
      )
    end
  end

  private

  # 管理者認証チェック
  #
  # current_admin が nil の場合、公開トップページへリダイレクト
  # Rails の標準的な認証パターンに準拠
  #
  # セキュリティログ:
  #   - 非管理者によるアクセス試行を警告ログに記録
  def authenticate_admin!
    return if current_admin

    # セキュリティ監査用ログ出力
    Rails.logger.warn(
      "非管理者による管理画面アクセス試行: " \
      "IP=#{request.remote_ip}, " \
      "Path=#{request.fullpath}, " \
      "Time=#{Time.current}"
    )

    redirect_to root_path, alert: 'この操作には管理者権限が必要です。'
  end

  # トピックをIDから取得
  #
  # ActiveRecord::RecordNotFound が発生した場合は rescue で処理
  # 不正なIDでアクセスされた場合、トピック一覧ページへリダイレクト
  #
  # インスタンス変数:
  #   @topic - 取得したトピックオブジェクト
  def set_topic
    @topic = Topic.find(params[:topic_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_topics_path, alert: FLASH_MESSAGES[:topic_not_found]
  end

  # トピックメンバーシップをIDから取得
  #
  # ActiveRecord::RecordNotFound が発生した場合は rescue で処理
  # 不正なIDでアクセスされた場合、メンバー一覧ページへリダイレクト
  #
  # インスタンス変数:
  #   @topic_membership - 取得したトピックメンバーシップオブジェクト
  #
  # 備考:
  #   - @topic.topic_memberships からの検索なので、他のトピックのメンバーシップは取得できない
  #   - これによりセキュリティが向上（他のトピックのメンバーを操作できない）
  def set_topic_membership
    @topic_membership = @topic.topic_memberships.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_back(
      fallback_location: admin_topic_members_path(@topic),
      alert: FLASH_MESSAGES[:membership_not_found]
    )
  end

  # ステータスが有効かどうかを検証
  #
  # SQL インジェクション対策のため、許可リストに含まれるかチェック
  #
  # @param status [String] 検証するステータス文字列
  # @return [Boolean] 有効な場合 true、無効な場合 false
  #
  # 許可される値:
  #   - 'approved' - 承認
  #   - 'rejected' - 拒否
  def valid_status?(status)
    PERMITTED_STATUSES.include?(status)
  end

  # バリデーションエラーメッセージを構築
  #
  # ActiveRecord のエラーメッセージを整形してユーザーに表示
  #
  # @param record [ActiveRecord::Base] エラーを持つレコード
  # @return [String] 整形されたエラーメッセージ
  #
  # 例:
  #   build_error_message(@topic_membership)
  #   # => "操作に失敗しました: ステータスは有効な値を入力してください"
  def build_error_message(record)
    return FLASH_MESSAGES[:update_failed] if record.errors.empty?

    "#{FLASH_MESSAGES[:update_failed]}: #{record.errors.full_messages.join(', ')}"
  end
end