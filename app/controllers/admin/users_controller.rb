# frozen_string_literal: true

# 管理者用ユーザー管理コントローラー
#
# 機能:
#   - ユーザーの一覧表示、詳細表示、編集、更新、削除
#   - 管理者のみアクセス可能
#
# 認証:
#   - authenticate_admin! で管理者権限をチェック
#   - 非管理者は公開トップページへリダイレクト
#
# ユーザー管理の主な用途:
#   - ユーザー情報の確認・編集
#   - アカウント停止（suspended フラグの管理）
#   - 不適切なユーザーの削除
class Admin::UsersController < ApplicationController
  # 定数定義
  # ページネーションの1ページあたりの表示件数
  PER_PAGE = 20

  # ソート可能なカラム（SQL インジェクション対策）
  PERMITTED_SORT_COLUMNS = %w[id name nickname created_at].freeze
  DEFAULT_SORT_COLUMN = 'id'
  DEFAULT_SORT_DIRECTION = 'asc'

  # フラッシュメッセージ
  FLASH_MESSAGES = {
    updated: 'ユーザー情報を更新しました。',
    destroyed: 'ユーザーを削除しました。',
    not_found: 'ユーザーが見つかりませんでした。'
  }.freeze

  # before_action フィルター
  before_action :authenticate_admin!
  before_action :set_user, only: %i[show edit update destroy]

  # GET /admin/users
  # ユーザー一覧表示
  #
  # 機能:
  #   - 並び替え: ID、名前、ニックネーム、作成日時
  #   - ページネーション: 1ページ20件
  #
  # パラメータ:
  #   - sort: ソート対象カラム（id, name, nickname, created_at）
  #   - direction: ソート方向（asc, desc）
  #   - page: ページ番号
  #
  # インスタンス変数:
  #   @users - ユーザー一覧
  def index
    # ソート設定（SQL インジェクション対策のため許可リストで検証）
    sort_column = sanitize_sort_column(params[:sort])
    sort_direction = sanitize_sort_direction(params[:direction])

    # ユーザー一覧を取得（ソートとページネーション適用）
    @users = User.order("#{sort_column} #{sort_direction}")
                 .page(params[:page])
                 .per(PER_PAGE)
  end

  # GET /admin/users/:id
  # ユーザー詳細表示
  #
  # @user は set_user で設定済み
  # ユーザーの詳細情報を表示
  def show; end

  # GET /admin/users/:id/edit
  # ユーザー編集フォーム
  #
  # @user は set_user で設定済み
  # ユーザー情報の編集フォームを表示
  def edit; end

  # PATCH/PUT /admin/users/:id
  # ユーザー情報を更新
  #
  # 成功時: ユーザー詳細ページへリダイレクト
  # 失敗時: 編集フォームを再表示
  #
  # 更新可能な属性:
  #   - name: ユーザー名
  #   - nickname: ニックネーム
  #   - email: メールアドレス
  #   - suspended: 停止フラグ（true の場合、アカウント停止）
  #   - profile_text: プロフィール文
  def update
    if @user.update(user_params)
      redirect_to admin_user_path(@user), notice: FLASH_MESSAGES[:updated]
    else
      # バリデーションエラー時は edit テンプレートを再表示
      flash.now[:alert] = build_error_message(@user)
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /admin/users/:id
  # ユーザーを削除
  #
  # 成功時: ユーザー一覧ページへリダイレクト
  # 失敗時: エラーメッセージを表示して一覧ページへリダイレクト
  #
  # 注意:
  #   - ユーザーに紐づく投稿やレビューが存在する場合、外部キー制約で削除できない可能性がある
  #   - その場合はエラーメッセージを表示
  #   - 本番環境では論理削除���soft delete）の検討を推奨
  def destroy
    if @user.destroy
      redirect_to admin_users_path, notice: FLASH_MESSAGES[:destroyed]
    else
      # 削除に失敗した場合（外部キー制約など）
      redirect_to admin_users_path,
                  alert: "削除できませんでした: #{@user.errors.full_messages.join(', ')}"
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

  # ユーザーをIDから取得
  #
  # ActiveRecord::RecordNotFound が発生した場合は rescue で処理
  # 不正なIDでアクセスされた場合、ユーザー一覧ページへリダイレクト
  #
  # インスタンス変数:
  #   @user - 取得したユーザーオブジェクト
  def set_user
    @user = User.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_users_path, alert: FLASH_MESSAGES[:not_found]
  end

  # ソート対象カラムをサニタイズ
  #
  # SQL インジェクション対策のため、許可リストに含まれるカラムのみ受け付ける
  #
  # @param column [String] リクエストパラメータで指定されたカラム名
  # @return [String] サニタイズされたカラム名
  def sanitize_sort_column(column)
    PERMITTED_SORT_COLUMNS.include?(column) ? column : DEFAULT_SORT_COLUMN
  end

  # ソート方向をサニタイズ
  #
  # asc または desc のみ受け付ける
  #
  # @param direction [String] リクエストパラメータで指定されたソート方向
  # @return [String] ���ニタイズされたソート方向（'asc' または 'desc'）
  def sanitize_sort_direction(direction)
    %w[asc desc].include?(direction) ? direction : DEFAULT_SORT_DIRECTION
  end

  # ストロングパラメータ
  #
  # 管理画面から編集可能にする属性を許可
  #
  # 許可するパラメータ:
  #   - name: ユーザー名
  #   - nickname: ニックネーム
  #   - email: メールアドレス
  #   - suspended: 停止フラグ（アカウント停止の管理）
  #   - profile_text: プロフィール文
  #
  # Mass Assignment 脆弱性を防ぐため、明示的に許可したパラメータのみ受け付ける
  #
  # 注意:
  #   - password や admin などの重要な属性は含めない
  #   - 必要に応じて別途専用のアクションを作成
  def user_params
    params.require(:user).permit(
      :name,
      :nickname,
      :email,
      :suspended,
      :profile_text
    )
  end

  # バリデーションエラーメッセージを構築
  #
  # ActiveRecord のエラーメッセージを整形してユーザーに表示
  #
  # @param record [ActiveRecord::Base] エラーを持つレコード
  # @return [String] 整形されたエラーメッセージ
  #
  # 例:
  #   build_error_message(@user)
  #   # => "保存できませんでした: 名前を入力してください, メールアドレスは不正な値です"
  def build_error_message(record)
    return '保存できませんでした。' if record.errors.empty?

    "保存できませんでした: #{record.errors.full_messages.join(', ')}"
  end
end