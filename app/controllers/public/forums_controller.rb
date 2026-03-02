# 公開用フォーラム管理コントローラー
#
# 機能:
#   - フォーラムの一覧表示、詳細表示
#   - フォーラムの作成、編集、更新、削除（管理者のみ）
#   - ログインユーザーのみアクセス可能
#
# 認証:
#   - authenticate_user! でログインユーザーをチェック
#   - require_admin! で管理者権限をチェック（作成・編集・削除時）
#
# フォーラムとは:
#   - ディスカッションの大分類（カテゴリ）
#   - 複数のトピック（スレッド）を含む
#   - 表示順序（position）で並び替え可能
class Public::ForumsController < ApplicationController
  # 定数定義
  # ページネーションの1ページあたりの表示件数
  PER_PAGE = 20

  # 最近のトピック表示件数
  RECENT_TOPICS_LIMIT = 10

  # フラッシュメッセージ
  FLASH_MESSAGES = {
    created: 'フォーラムを作成しました。',
    create_failed: 'フォーラムの作成に失敗しました。入力内容を確認してください。',
    updated: 'フォーラムを更新しました。',
    update_failed: 'フォーラムの更新に失敗しました。入力内容を確認してください。',
    destroyed: 'フォーラムを削除しました。',
    destroy_failed: 'フォーラムの削除に失敗しました。',
    not_found: 'フォーラムが見つかりませんでした。',
    unauthorized: 'この操作を行う権限がありません。'
  }.freeze

  # before_action フィルター
  # 認証チェック: 全アクションでログイン必須
  before_action :authenticate_user!

  # 管理者チェック: 作成・編集・削除は管理者のみ
  before_action :require_admin!, only: %i[new create edit update destroy]

  # フォーラム取得: 詳細・編集・更新・削除で使用
  before_action :set_forum, only: %i[show edit update destroy]

  # GET /forums
  # フォーラム一覧表示
  #
  # 並び順: position の昇順（管理者が設定した表示順序）
  # ページネーション: Kaminari または WillPaginate を自動判定
  #
  # インスタンス変数:
  #   @forums - フォーラム一覧
  def index
    @forums = Forum.order(position: :asc)
    @forums = paginate(@forums)
  end

  # GET /forums/:id
  # フォーラム詳細表示
  #
  # 機能:
  #   - フォーラム情報の表示
  #   - 最近更新されたトピック一覧を表示（最大10件）
  #
  # インスタンス変数:
  #   @forum - フォーラム詳細（set_forum で設定済み）
  #   @recent_topics - 最近更新されたトピック一覧（更新日時の降順）
  def show
    # @forum は set_forum で取得済み

    # フォーラム詳細に最近のトピックや統計情報を表示
    @recent_topics = @forum.topics
                           .order(updated_at: :desc)
                           .limit(RECENT_TOPICS_LIMIT)
  end

  # GET /forums/new
  # 新規フォーラム作成フォーム
  #
  # 管理者のみアクセス可能（require_admin! でチェック済み）
  def new
    @forum = Forum.new
  end

  # POST /forums
  # フォーラムを作成
  #
  # 管理者のみアクセス可能（require_admin! でチェック済み）
  #
  # 成功時: フォーラム一覧ページへリダイレクト
  # 失敗時: 作成フォームを再表示
  #
  # 作成者情報:
  #   - creator_id カラムが存在する場合、現在のユーザーIDを設定
  def create
    @forum = Forum.new(forum_params)

    # 作成者情報を設定（カラムが存在する場合のみ）
    @forum.creator_id = current_user.id if @forum.respond_to?(:creator_id)

    if @forum.save
      redirect_to forums_path, notice: FLASH_MESSAGES[:created]
    else
      # バリデーションエラー時は new テンプレートを再表示
      flash.now[:alert] = build_error_message(@forum, FLASH_MESSAGES[:create_failed])
      render :new, status: :unprocessable_entity
    end
  end

  # GET /forums/:id/edit
  # フォーラム編集フォーム
  #
  # 管理者のみアクセス可能（require_admin! でチェック済み）
  # @forum は set_forum で設定済み
  def edit; end

  # PATCH/PUT /forums/:id
  # フォーラムを更新
  #
  # 管理者のみアクセス可能（require_admin! でチェック済み）
  #
  # 成功時: フォーラム一覧ページへリダイレクト
  # 失敗時: 編集フォームを再表示
  def update
    if @forum.update(forum_params)
      redirect_to forums_path, notice: FLASH_MESSAGES[:updated]
    else
      # バリデーションエラー時は edit テンプレートを再表示
      flash.now[:alert] = build_error_message(@forum, FLASH_MESSAGES[:update_failed])
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /forums/:id
  # フォーラムを削除
  #
  # 管理者のみアクセス可能（require_admin! でチェック済み）
  #
  # 成功時: フォーラム一覧ページへリダイレクト
  # 失敗時: エラーメッセージを表示してフォーラム一覧ページへリダイレクト
  #
  # 注意:
  #   - フォーラムに紐づくトピックや投稿が存在する場合、外部キー制約で削除できない可能性がある
  #   - その場合はエラーメッセージを表示
  def destroy
    if @forum.destroy
      redirect_to forums_path, notice: FLASH_MESSAGES[:destroyed]
    else
      # 削除に失敗した場合（外部キー制約など）
      redirect_to forums_path,
                  alert: "#{FLASH_MESSAGES[:destroy_failed]}: #{@forum.errors.full_messages.join(', ')}"
    end
  end

  private

  # フォーラムをIDから取得
  #
  # ActiveRecord::RecordNotFound が発生した場合は rescue で処理
  # 不正なIDでアクセスされた場合、フォーラム一覧ページへリダイレクト
  #
  # インスタンス変数:
  #   @forum - 取得したフォーラムオブジェクト
  def set_forum
    @forum = Forum.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to forums_path, alert: FLASH_MESSAGES[:not_found]
  end

  # ストロングパラメータ
  #
  # 許可するパラメータ:
  #   - title: フォーラムタイトル
  #   - description: フォーラム説明
  #   - public: 公開/非公開フラグ
  #   - position: 表示順序
  #
  # Mass Assignment 脆弱性を防ぐため、明示的に許可したパラメータのみ受け付ける
  def forum_params
    params.require(:forum).permit(:title, :description, :public, :position)
  end

  # 管理者権限チェック
  #
  # 管理者以外は全ての管理操作（作成・編集・削除）を禁ずる
  #
  # current_user が nil の場合や admin? が false の場合、
  # ルートページへリダイレクトして警告メッセージを表示
  #
  # セキュリティログ:
  #   - 非管理者による管理操作試行を警告ログに記録
  def require_admin!
    unless current_user&.admin?
      # セキュリティ監査用ログ出力
      Rails.logger.warn(
        "非管理者によるフォーラム管理操作試行: " \
        "User ID=#{current_user&.id || 'nil'}, " \
        "IP=#{request.remote_ip}, " \
        "Path=#{request.fullpath}, " \
        "Time=#{Time.current}"
      )

      redirect_to root_path, alert: FLASH_MESSAGES[:unauthorized]
    end
  end

  # ページネーション用ヘルパー
  #
  # Kaminari/WillPaginate の両方に対応
  # インストールされているライブラリを自動判定して適切なメソッドを呼び出す
  #
  # @param scope [ActiveRecord::Relation] ページネーション対象のスコープ
  # @return [ActiveRecord::Relation] ページネーションが適用されたスコープ
  #
  # サポートライブラリ:
  #   - Kaminari: .page(params[:page]) を使用
  #   - WillPaginate: .paginate(page: params[:page]) を使用
  #   - 両方とも未インストールの場合: 元のスコープをそのまま返す
  def paginate(scope)
    if defined?(Kaminari)
      # Kaminari が利用可能な場合
      scope.page(params[:page]).per(PER_PAGE)
    elsif defined?(WillPaginate)
      # WillPaginate が利用可能な場合
      scope.paginate(page: params[:page], per_page: PER_PAGE)
    else
      # ページネーションライブラリが未インストールの場合
      Rails.logger.warn('ページネーションライブラリ（Kaminari/WillPaginate）が見つかりません。')
      scope
    end
  end

  # バリデーションエラーメッセージを構築
  #
  # ActiveRecord のエラーメッセージを整形してユーザーに表示
  #
  # @param record [ActiveRecord::Base] エラーを持つレコード
  # @param default_message [String] デフォルトのエラーメッセージ
  # @return [String] 整形されたエラーメッセージ
  #
  # 例:
  #   build_error_message(@forum, FLASH_MESSAGES[:create_failed])
  #   # => "フォーラムの作成に失敗しました。入力内容を確認してください。タイトルを入力してください"
  def build_error_message(record, default_message)
    return default_message if record.errors.empty?

    errors = record.errors.full_messages.join(', ')
    "#{default_message} #{errors}"
  end
end