# 管理者用フォーラム管理コントローラー
#
# 機能:
#   - フォーラムの一覧表示、作成、編集、更新、削除
#   - 管理者のみアクセス可能
#
# 認証:
#   - before_action で管理者権限をチェック
#   - 非管理者は公開トップページへリダイレクト
class Admin::ForumsController < ApplicationController
  # 定数定義
  # ページネーションの1ページあたりの表示件数
  PER_PAGE = 20

  # フラッシュメッセージ
  FLASH_MESSAGES = {
    created: 'フォーラムを作成しました。',
    updated: 'フォーラムを更新しました。',
    destroyed: 'フォーラムを削除しました。',
    not_found: 'フォーラムが見つかりませんでした。'
  }.freeze

  # before_action フィルター
  before_action :authenticate_admin!
  before_action :set_forum, only: %i[edit update destroy]

  # GET /admin/forums
  # フォーラム一覧表示
  #
  # 並び順: position の昇順
  # ページネーション: Kaminari を使用（1ページ20件）
  def index
    @forums = Forum.order(position: :asc)
                   .page(params[:page])
                   .per(PER_PAGE)
  end

  # GET /admin/forums/new
  # 新規フォーラム作成フォーム
  def new
    @forum = Forum.new
  end

  # POST /admin/forums
  # フォーラムを作成
  #
  # 成功時: 一覧ページへリダイレクト
  # 失敗時: 作成フォームを再表示
  def create
    @forum = Forum.new(forum_params)

    if @forum.save
      redirect_to admin_forums_path, notice: FLASH_MESSAGES[:created]
    else
      # バリデーションエラー時は new テンプレートを再表示
      flash.now[:alert] = build_error_message(@forum)
      render :new, status: :unprocessable_entity
    end
  end

  # GET /admin/forums/:id/edit
  # フォーラム編集フォーム
  #
  # @forum は set_forum で設定済み
  def edit; end

  # PATCH/PUT /admin/forums/:id
  # フォーラムを更新
  #
  # 成功時: 一覧ページへリダイレクト
  # 失敗時: 編集フォームを再表示
  def update
    if @forum.update(forum_params)
      redirect_to admin_forums_path, notice: FLASH_MESSAGES[:updated]
    else
      # バリデーションエラー時は edit テンプレートを再表示
      flash.now[:alert] = build_error_message(@forum)
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /admin/forums/:id
  # フォーラムを削除
  #
  # 成功時: 一覧ページへリダイレクト
  # 失敗時: エラーメッセージを表示して一覧ページへリダイレクト
  def destroy
    if @forum.destroy
      redirect_to admin_forums_path, notice: FLASH_MESSAGES[:destroyed]
    else
      # 削除に失敗した場合（外部キー制約など）
      redirect_to admin_forums_path, 
                  alert: "削除できませんでした: #{@forum.errors.full_messages.join(', ')}"
    end
  end

  private

  # 管理者認証チェック
  #
  # current_admin が nil の場合、公開トップページへリダイレクト
  # Rails の標準的な認証パターンに準拠
  def authenticate_admin!
    return if current_admin

    # ログ出力（セキュリティ監査用）
    Rails.logger.warn("非管理者による管理画面アクセス試行: IP=#{request.remote_ip}")
    
    redirect_to root_path, alert: 'この操作には管理者権限が必要です。'
  end

  # フォーラムをIDから取得
  #
  # ActiveRecord::RecordNotFound が発生した場合は rescue_from で処理
  # または ApplicationController で一括処理を推奨
  def set_forum
    @forum = Forum.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_forums_path, alert: FLASH_MESSAGES[:not_found]
  end

  # ストロングパラメータ
  #
  # 許可するパラメータ:
  #   - title: フォーラム名
  #   - description: フォーラム説明
  #   - public: 公開/非公開フラグ
  #   - position: 表示順序
  def forum_params
    params.require(:forum)
          .permit(:title, :description, :public, :position)
  end

  # バリデーションエラーメッセージを構築
  #
  # @param record [ActiveRecord::Base] エラーを持つレコード
  # @return [String] エラーメッセージ
  def build_error_message(record)
    return '保存できませんでした。' if record.errors.empty?

    "保存できませんでした: #{record.errors.full_messages.join(', ')}"
  end
end