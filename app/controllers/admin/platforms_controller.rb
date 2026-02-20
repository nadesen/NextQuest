# 管理者用プラットフォーム管理コントローラー
#
# 機能:
#   - プラットフォームの一覧表示、作成、編集、更新、削除
#   - 管理者のみアクセス可能
#
# 認証:
#   - before_action で管理者権限をチェック
#   - 非管理者は公開トップページへリダイレクト
#
# プラットフォームとは:
#   - ゲームのプラットフォーム（PS5、Nintendo Switch、Xbox など）を管理
class Admin::PlatformsController < ApplicationController
  # 定数定義
  # ページネーションの1ページあたりの表示件数
  PER_PAGE = 20

  # フラッシュメッセージ
  FLASH_MESSAGES = {
    created: 'プラットフォームを作成しました。',
    updated: 'プラットフォームを更新しました。',
    destroyed: 'プラットフォームを削除しました。',
    not_found: 'プラットフォームが見つかりませんでした。'
  }.freeze

  # before_action フィルター
  before_action :authenticate_admin!
  before_action :set_platform, only: %i[edit update destroy]

  # GET /admin/platforms
  # プラットフォーム一覧表示
  #
  # 並び順: ID の昇順
  # ページネーション: Kaminari を使用（1ページ20件）
  def index
    @platforms = Platform.order(id: :asc)
                         .page(params[:page])
                         .per(PER_PAGE)
  end

  # GET /admin/platforms/new
  # 新規プラットフォーム作成フォーム
  def new
    @platform = Platform.new
  end

  # POST /admin/platforms
  # プラットフォームを作成
  #
  # 成功時: 一覧ページへリダイレクト
  # 失敗時: 作成フォームを再表示
  def create
    @platform = Platform.new(platform_params)

    if @platform.save
      redirect_to admin_platforms_path, notice: FLASH_MESSAGES[:created]
    else
      # バリデーションエラー時は new テンプレートを再表示
      flash.now[:alert] = build_error_message(@platform)
      render :new, status: :unprocessable_entity
    end
  end

  # GET /admin/platforms/:id/edit
  # プラットフォーム編集フォーム
  #
  # @platform は set_platform で設定済み
  def edit; end

  # PATCH/PUT /admin/platforms/:id
  # プラットフォームを更新
  #
  # 成功時: 一覧ページへリダイレクト
  # 失敗時: 編集フォームを再表示
  def update
    if @platform.update(platform_params)
      redirect_to admin_platforms_path, notice: FLASH_MESSAGES[:updated]
    else
      # バリデーションエラー時は edit テンプレートを再表示
      flash.now[:alert] = build_error_message(@platform)
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /admin/platforms/:id
  # プラットフォームを削除
  #
  # 成功時: 一覧ページへリダイレクト
  # 失敗時: エラーメッセージを表示して一覧ページへリダイレクト
  #
  # 注意:
  #   - プラットフォームに紐づくゲームが存在する場合、外部キー制約で削除できない可能性がある
  #   - その場合はエラーメッセージを表示
  def destroy
    if @platform.destroy
      redirect_to admin_platforms_path, notice: FLASH_MESSAGES[:destroyed]
    else
      # 削除に失敗した場合（外部キー制約など）
      redirect_to admin_platforms_path,
                  alert: "削除できませんでした: #{@platform.errors.full_messages.join(', ')}"
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

  # プラットフォームをIDから取得
  #
  # ActiveRecord::RecordNotFound が発生した場合は rescue で処理
  # 不正なIDでアクセスされた場合、一覧ページへリダイレクト
  def set_platform
    @platform = Platform.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_platforms_path, alert: FLASH_MESSAGES[:not_found]
  end

  # ストロングパラメータ
  #
  # 許可するパラメータ:
  #   - name: プラットフォーム名
  #
  # Mass Assignment 脆弱性を防ぐため、明示的に許可したパラメータのみ受け付ける
  def platform_params
    params.require(:platform).permit(:name)
  end

  # バリデーションエラーメッセージを構築
  #
  # ActiveRecord のエラーメッセージを整形してユーザーに表示
  #
  # @param record [ActiveRecord::Base] エラーを持つレコード
  # @return [String] 整形されたエラーメッセージ
  #
  # 例:
  #   build_error_message(@platform)
  #   # => "保存できませんでした: 名前を入力してください"
  def build_error_message(record)
    return '保存できませんでした。' if record.errors.empty?

    "保存できませんでした: #{record.errors.full_messages.join(', ')}"
  end
end