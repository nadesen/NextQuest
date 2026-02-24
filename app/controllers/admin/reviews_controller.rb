# 管理者用レビュー管理コントローラー
#
# 機能:
#   - ゲームレビューの一覧表示、詳細表示、編集、更新、削除
#   - 管理者のみアクセス可能
#
# 認証:
#   - authenticate_admin! で管理者権限をチェック
#   - 非管理者は公開トップページへリダイレクト
#
# レビューとは:
#   - ユーザーが投稿したゲームレビュー
#   - プラットフォーム（PS5、Switch など）やジャンルで分類
#   - 承認機能（approved）で公開/非公開を管理
class Admin::ReviewsController < ApplicationController
  # 定数定義
  # ページネーションの1ページあたりの表示件数
  PER_PAGE = 20

  # ソート可能なカラム（SQL インジェクション対策）
  PERMITTED_SORT_COLUMNS = %w[id title user_id].freeze
  DEFAULT_SORT_COLUMN = 'id'
  DEFAULT_SORT_DIRECTION = 'asc'

  # レビューコメントのソート可能なカラム
  PERMITTED_COMMENT_SORT_COLUMNS = %w[score created_at].freeze
  DEFAULT_COMMENT_SORT_COLUMN = 'created_at'
  DEFAULT_COMMENT_SORT_DIRECTION = 'desc'

  # フラッシュメッセージ
  FLASH_MESSAGES = {
    updated: 'レビューを更新しました。',
    destroyed: 'レビューを削除しました。',
    not_found: 'レビューが見つかりませんでした。'
  }.freeze

  # before_action フィルター
  before_action :authenticate_admin!
  before_action :set_review, only: %i[show edit update destroy]
  before_action :load_filter_collections, only: %i[index]
  before_action :load_form_collections, only: %i[edit update]

  # GET /admin/reviews
  # レビュー一覧表示
  #
  # 機能:
  #   - 並び替え: ID、タイトル、ユーザーID
  #   - 絞り込み: プラットフォーム、ジャンル
  #   - ページネーション: 1ページ20件
  #
  # パラメータ:
  #   - sort: ソート対象カラム（id, title, user_id）
  #   - direction: ソート方向（asc, desc）
  #   - platform_id: プラットフォームID（絞り込み）
  #   - genre_id: ジャンルID（絞り込み）
  #   - page: ページ番号
  def index
    # ソート設定（SQL インジェクション対策のため許可リストで検証）
    sort_column = sanitize_sort_column(params[:sort], PERMITTED_SORT_COLUMNS, DEFAULT_SORT_COLUMN)
    sort_direction = sanitize_sort_direction(params[:direction], DEFAULT_SORT_DIRECTION)

    # 基本クエリ（N+1 問題対策で関連データを事前読み込み）
    @reviews = Review.includes(:user, :platform, :genre)

    # 絞り込み条件の適用
    @reviews = apply_filters(@reviews)

    # ソートとページネーション
    @reviews = @reviews.order("#{sort_column} #{sort_direction}")
                       .page(params[:page])
                       .per(PER_PAGE)
  end

  # GET /admin/reviews/:id
  # レビュー詳細表示
  #
  # 機能:
  #   - レビュー本体の表示
  #   - 関連するコメント一覧を並び替え可能
  #
  # パラメータ:
  #   - sort_type: コメントのソート対象（score, created_at）
  #   - sort_order: ソート方向（asc, desc）
  #
  # @review は set_review で設定済み
  def show
    # コメントのソート設定
    sort_type = sanitize_sort_column(
      params[:sort_type],
      PERMITTED_COMMENT_SORT_COLUMNS,
      DEFAULT_COMMENT_SORT_COLUMN
    )
    sort_order = sanitize_sort_direction(
      params[:sort_order],
      DEFAULT_COMMENT_SORT_DIRECTION
    )

    # レビューコメント一覧を取得（ソート適用）
    @review_comments = @review.review_comments
                              .order("#{sort_type} #{sort_order}")
  end

  # GET /admin/reviews/:id/edit
  # レビュー編集フォーム
  #
  # @review は set_review で設定済み
  # @platforms, @genres は load_form_collections で設定済み
  def edit; end

  # PATCH/PUT /admin/reviews/:id
  # レビューを更新
  #
  # 成功時: レビュー詳細ページへリダイレクト
  # 失敗時: 編集フォームを再表示
  #
  # 更新可能な属性:
  #   - title: レビュータイトル
  #   - content: レビュー内容
  #   - rating: 評価点数
  #   - play_time: プレイ時間
  #   - platform_id: プラットフォームID
  #   - genre_id: ジャンルID
  #   - approved: 承認フラグ（公開/非公開の制御）
  def update
    if @review.update(review_params)
      redirect_to admin_review_path(@review), notice: FLASH_MESSAGES[:updated]
    else
      # バリデーションエラー時は edit テンプレートを再表示
      # load_form_collections は before_action で呼ばれているので view 用のデータは揃っています
      flash.now[:alert] = build_error_message(@review)
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /admin/reviews/:id
  # レビューを削除
  #
  # 成功時: レビュー一覧ページへリダイレクト
  # 失敗時: エラーメッセージを表示して一覧ページへリダイレクト
  #
  # 注意:
  #   - レビューに紐づくコメントが存在する場合、外部キー制約で削除できない可能性がある
  #   - その場合はエラーメッセージを表示
  def destroy
    if @review.destroy
      redirect_to admin_reviews_path, notice: FLASH_MESSAGES[:destroyed]
    else
      # 削除に失敗した場合（外部キー制約など）
      redirect_to admin_reviews_path,
                  alert: "削除できませんでした: #{@review.errors.full_messages.join(', ')}"
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

  # レビューをIDから取得
  #
  # ActiveRecord::RecordNotFound が発生した場合は rescue で処理
  # 不正なIDでアクセスされた場合、レビュー一覧ページへリダイレクト
  def set_review
    @review = Review.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_reviews_path, alert: FLASH_MESSAGES[:not_found]
  end

  # フィルタ用の選択肢を読み込み（一覧画面用）
  #
  # インスタンス変数:
  #   @platforms - プラットフォーム一覧（名前順）
  #   @genres - ジャンル一覧（名前順）
  def load_filter_collections
    @platforms = Platform.order(:name)
    @genres = Genre.order(:name)
  end

  # フォーム用の選択肢を読み込み（編集画面用）
  #
  # インスタンス変数:
  #   @platforms - プラットフォーム一覧（名前順）
  #   @genres - ジャンル一覧（名前順）
  #
  # 備考:
  #   load_filter_collections と同じ処理だが、用途が異なるため別メソッドとして定義
  #   将来的に選択肢の内容が変わる可能性を考慮
  def load_form_collections
    @platforms = Platform.order(:name)
    @genres = Genre.order(:name)
  end

  # 絞り込み条件を適用
  #
  # @param relation [ActiveRecord::Relation] レビューのクエリ
  # @return [ActiveRecord::Relation] 絞り込み条件を適用したクエリ
  #
  # 絞り込み条件:
  #   - platform_id: プラットフォームIDで絞り込み
  #   - genre_id: ジャンルIDで絞り込み
  def apply_filters(relation)
    # プラットフォームで絞り込み
    relation = relation.where(platform_id: params[:platform_id]) if params[:platform_id].present?

    # ジャンルで絞り込み
    relation = relation.where(genre_id: params[:genre_id]) if params[:genre_id].present?

    relation
  end

  # ソート対象カラムをサニタイズ
  #
  # SQL インジェクション対策のため、許可リストに含まれるカラムのみ受け付ける
  #
  # @param column [String] リクエストパラメータで指定されたカラム名
  # @param permitted_columns [Array<String>] 許可するカラム名のリスト
  # @param default_column [String] デフォルトのカラム名
  # @return [String] サニタイズされたカラム名
  def sanitize_sort_column(column, permitted_columns, default_column)
    permitted_columns.include?(column) ? column : default_column
  end

  # ソート方向をサニタイズ
  #
  # asc または desc のみ受け付ける
  #
  # @param direction [String] リクエストパラメータで指定されたソート方向
  # @param default_direction [String] デフォルトのソート方向
  # @return [String] サニタイズされたソート方向（'asc' または 'desc'）
  def sanitize_sort_direction(direction, default_direction)
    %w[asc desc].include?(direction) ? direction : default_direction
  end

  # ストロングパラメータ
  #
  # 管理画面から編集可能にする属性を許可
  #
  # 許可するパラメータ:
  #   - title: レビュータイトル
  #   - content: レビュー内容
  #   - rating: 評価点数
  #   - play_time: プレイ時間
  #   - platform_id: プラットフォームID
  #   - genre_id: ジャンルID
  #   - approved: 承認フラグ（管理画面では必ず許可）
  #
  # Mass Assignment 脆弱性を防ぐため、明示的に許可したパラメータのみ受け付ける
  def review_params
    params.require(:review).permit(
      :title,
      :content,
      :rating,
      :play_time,
      :platform_id,
      :genre_id,
      :approved
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
  #   build_error_message(@review)
  #   # => "保存できませんでした: タイトルを入力してください, 評価は数値で入力してください"
  def build_error_message(record)
    return '保存できませんでした。' if record.errors.empty?

    "保存できませんでした: #{record.errors.full_messages.join(', ')}"
  end
end