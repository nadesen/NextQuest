# 管理者用トピック管理コントローラー
#
# 機能:
#   - フォーラムトピックの一覧表示、詳細表示、更新、削除
#   - 管理者のみアクセス可能
#
# 認証:
#   - authenticate_admin! で管理者権限をチェック
#   - 非管理者は公開トップページへリダイレクト
#
# トピックとは:
#   - フォーラム内のディスカッションスレッド
#   - 複数の投稿（posts）を含む
#   - ロック機能で新規投稿を制限可能
class Admin::TopicsController < ApplicationController
  # 定数定義
  # ページネーションの1ページあたりの表示件数
  PER_PAGE = 20

  # ソート可能なカラム（SQL インジェクション対策）
  PERMITTED_SORT_COLUMNS = %w[id title creator_id posts_count created_at].freeze
  DEFAULT_SORT_COLUMN = 'id'
  DEFAULT_SORT_DIRECTION = 'asc'

  # フラッシュメッセージ
  FLASH_MESSAGES = {
    updated: 'トピックを更新しました。',
    destroyed: 'トピックを削除しました。',
    not_found: 'トピックが見つかりませんでした。',
    forum_not_found: '指定されたフォーラムが見つかりませんでした。'
  }.freeze

  # before_action フィルター
  before_action :authenticate_admin!
  before_action :set_topic, only: %i[show update destroy]

  # GET /admin/topics
  # トピック一覧表示
  #
  # 機能:
  #   - 並び替え: ID、タイトル、作成者ID、投稿数、作成日時
  #   - 絞り込み: フォーラムID
  #   - ページネーション: 1ページ20件
  #
  # パラメータ:
  #   - sort: ソート対象カラム（id, title, creator_id, posts_count, created_at）
  #   - direction: ソート方向（asc, desc）
  #   - forum_id: フォーラムID（絞り込み）
  #   - page: ページ番号
  #
  # インスタンス変数:
  #   @topics - トピック一覧
  #   @forum - 絞り込み対象のフォーラム（forum_id が指定された場合のみ）
  def index
    # ソート設定（SQL インジェクション対策のため許可リストで検証）
    sort_column = sanitize_sort_column(params[:sort])
    sort_direction = sanitize_sort_direction(params[:direction])

    # 基本クエリ（N+1 問題対策で関連データを事前読み込み）
    @topics = Topic.includes(:forum, :creator)

    # フォーラムで絞り込み
    if params[:forum_id].present?
      @forum = find_forum_for_filter(params[:forum_id])
      @topics = @topics.where(forum_id: @forum.id) if @forum
    end

    # ソートとページネーション
    @topics = @topics.order("#{sort_column} #{sort_direction}")
                     .page(params[:page])
                     .per(PER_PAGE)
  end

  # GET /admin/topics/:id
  # トピック詳細表示
  #
  # 機能:
  #   - トピック情報の表示
  #   - 関連する投稿一覧を時系列順に表示
  #   - ページネーション: 1ページ20件
  #
  # インスタンス変数:
  #   @topic - トピック詳細（set_topic で設定済み）
  #   @posts - トピックに属する投稿一覧（作成日時の昇順）
  def show
    # トピック本体
    # @topic は before_action/set_topic で読み込み済み

    # 関連する投稿を取得（作成順で表示）
    @posts = @topic.posts
                   .order(created_at: :asc)
                   .page(params[:page])
                   .per(PER_PAGE)
  end

  # PATCH/PUT /admin/topics/:id
  # トピックを更新
  #
  # 成功時: トピック詳細ページへリダイレクト
  # 失敗時: 詳細ページ（編集フォーム）を再表示
  #
  # 更新可能な属性:
  #   - title: トピックタイトル
  #   - description: トピック説明
  #   - locked: ロックフラグ（true の場合、新規投稿を制限）
  def update
    if @topic.update(topic_params)
      redirect_to admin_topic_path(@topic), notice: FLASH_MESSAGES[:updated]
    else
      # バリデーションエラー時は show テンプレートを再表示
      flash.now[:alert] = build_error_message(@topic)

      # ビューで必要な投稿一覧を再読み込み
      @posts = @topic.posts
                     .order(created_at: :asc)
                     .page(params[:page])
                     .per(PER_PAGE)

      render :show, status: :unprocessable_entity
    end
  end

  # DELETE /admin/topics/:id
  # トピックを削除
  #
  # 成功時: トピック一覧ページへリダイレクト
  # 失敗時: エラーメッセージを表示して一覧ページへリダイレクト
  #
  # 注意:
  #   - トピックに紐づく投稿やメンバーシップが存在する場合、外部キー制約で削除できない可能性がある
  #   - その場合はエラーメッセージを表示
  def destroy
    if @topic.destroy
      redirect_to admin_topics_path, notice: FLASH_MESSAGES[:destroyed]
    else
      # 削除に失敗した場合（外部キー制約など）
      redirect_to admin_topics_path,
                  alert: "削除できませんでした: #{@topic.errors.full_messages.join(', ')}"
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
    @topic = Topic.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_topics_path, alert: FLASH_MESSAGES[:not_found]
  end

  # フォーラムを検索（絞り込み用）
  #
  # find_by を使用して、存在しない場合でも例外を発生させない
  # フォーラムが見つからない場合は警告ログを出力
  #
  # @param forum_id [String, Integer] フォーラムID
  # @return [Forum, nil] 見つかったフォーラムオブジェクト、または nil
  def find_forum_for_filter(forum_id)
    forum = Forum.find_by(id: forum_id)

    unless forum
      # フォーラムが見つからない場合は警告ログを出力
      Rails.logger.warn(
        "存在しないフォーラムIDでの絞り込み試行: " \
        "forum_id=#{forum_id}, " \
        "IP=#{request.remote_ip}"
      )
    end

    forum
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
  # @return [String] サニタイズされたソート方向（'asc' または 'desc'）
  def sanitize_sort_direction(direction)
    %w[asc desc].include?(direction) ? direction : DEFAULT_SORT_DIRECTION
  end

  # ストロングパラメータ
  #
  # 管理画面から編集可能にする属性を許可
  #
  # 許可するパラメータ:
  #   - title: トピックタイトル
  #   - description: トピック説明
  #   - locked: ロックフラグ（true の場合、新規投稿を制限）
  #
  # Mass Assignment 脆弱性を防ぐため、明示的に許可したパラメータのみ受け付ける
  def topic_params
    params.require(:topic).permit(:title, :description, :locked)
  end

  # バリデーションエラーメッセージを構築
  #
  # ActiveRecord のエラーメッセージを整形してユーザーに表示
  #
  # @param record [ActiveRecord::Base] エラーを持つレコード
  # @return [String] 整形されたエラーメッセージ
  #
  # 例:
  #   build_error_message(@topic)
  #   # => "保存できませんでした: タイトルを入力してください"
  def build_error_message(record)
    return '保存できませんでした。' if record.errors.empty?

    "保存できませんでした: #{record.errors.full_messages.join(', ')}"
  end
end