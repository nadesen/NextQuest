# 公開用投稿管理コントローラー
#
# 機能:
#   - フォーラムトピック内への投稿作成
#   - 投稿の編集・削除
#   - ログインユーザーのみアクセス可能
#   - ゲストユーザーは利用不可
#
# 認証・認可:
#   - authenticate_user! でログインユーザーをチェック
#   - forbid_guest_user! でゲストユーザーを除外
#   - authorize_post_owner! で投稿の所有者または管理者のみ編集・削除可能
#   - authorize_posting! でトピックへの投稿権限をチェック
#
# トピックへの投稿権限:
#   - トピックの作成者
#   - トピックの承認済みメンバー
#   - 管理者
#
# ロック機能:
#   - トピックがロックされている場合、管理者以外は投稿不可
class Public::PostsController < ApplicationController
  # 定数定義
  # ページネーションの1ページあたりの表示件数
  PER_PAGE = 20

  # ゲストユーザーのメールアドレス
  GUEST_USER_EMAIL = 'guest@example.com'

  # フラッシュメッセージ
  FLASH_MESSAGES = {
    created: '投稿しました。',
    create_failed: '投稿に失敗しました。',
    destroyed: '投稿を削除しました。',
    destroy_failed: '投稿の削除に失敗しました。',
    unauthorized_edit: '編集権限がありません。投稿一覧に戻ります。',
    posting_forbidden: '投稿するには参加が必要です。参加申請を送信してください。',
    topic_locked: 'このトピックはロックされているため投稿できません。',
    guest_user_forbidden: 'ゲストユーザーは投稿機能を利用できません。',
    forum_not_found: 'フォーラムが見つかりませんでした。',
    topic_not_found: 'トピックが見つかりませんでした。',
    post_not_found: '投稿が見つかりませんでした。'
  }.freeze

  # before_action フィルター
  # 認証チェック: 全アクションでログイン必須
  before_action :authenticate_user!, only: %i[create destroy edit update]

  # ゲストユーザーチェック: ゲストユーザーは投稿機能を利用不可
  before_action :forbid_guest_user!, only: %i[create edit update destroy]

  # フォーラムとトピックの取得
  before_action :set_forum_and_topic, only: %i[create destroy edit update]

  # 投稿の取得
  before_action :set_post, only: %i[destroy edit update]

  # 投稿権限チェック: 作成時
  before_action :authorize_posting!, only: %i[create]

  # 所有者権限チェック: 編集・削除時
  before_action :authorize_post_owner!, only: %i[destroy edit update]

  # POST /forums/:forum_id/topics/:topic_id/posts
  # トピックに投稿を作成
  #
  # 処理フロー:
  #   1. トピックのロック状態をチェック（管理者以外はロック時投稿不可）
  #   2. 投稿を作成（creator_id に現在のユーザーを設定）
  #   3. 成功/失敗に応じてレスポンス
  #
  # レスポンス:
  #   - 成功時: JS（Ajax）または HTML でリダイレクト
  #   - 失敗時: エラーメッセージを表示
  #
  # 備考:
  #   - Ajax 対応（format.js）
  #   - ページネーション適用済みの投稿一覧を取得
  def create
    # ロック済みトピックへの投稿は管理者以外不可
    if topic_locked_for_current_user?
      respond_with_lock_forbidden
      return
    end

    # 投稿を作成
    @post = build_post

    if @post.save
      # 成功時: 投稿一覧を更新
      @posts = fetch_paginated_posts

      respond_to do |format|
        format.js
        format.html { redirect_to forum_topic_path(@forum, @topic), notice: FLASH_MESSAGES[:created] }
      end
    else
      # 失敗時: エラーメッセージを表示
      handle_create_failure
    end
  end

  # DELETE /forums/:forum_id/topics/:topic_id/posts/:id
  # 投稿を削除
  #
  # 処理フロー:
  #   1. 投稿を削除
  #   2. 成功/失敗に応じてレスポンス
  #
  # レスポンス:
  #   - 成功時: JS（Ajax）または HTML でリダイレクト
  #   - 失敗時: エラーメッセージを表示
  #
  # 備考:
  #   - Ajax 対応（format.js）
  #   - ページネーション適用済みの投稿一覧を取得
  def destroy
    if @post.destroy
      # 成功時: 投稿一覧を更新
      @posts = fetch_paginated_posts

      respond_to do |format|
        format.js
        format.html { redirect_to forum_topic_path(@forum, @topic), notice: FLASH_MESSAGES[:destroyed] }
      end
    else
      # 失敗時: エラーメッセージを表示
      handle_destroy_failure
    end
  end

  # GET /forums/:forum_id/topics/:topic_id/posts/:id/edit
  # 投稿編集フォーム
  #
  # @forum, @topic, @post は before_action で設定済み
  def edit; end

  # PATCH/PUT /forums/:forum_id/topics/:topic_id/posts/:id
  # 投稿を更新
  #
  # 処理フロー:
  #   1. 投稿を更新
  #   2. 成功/失敗に応じてレスポンス
  #
  # レスポンス:
  #   - 成功時: トピック詳細ページへリダイレクト
  #   - 失敗時: 編集フォームを再表示
  def update
    if @post.update(post_params)
      redirect_to forum_topic_path(@forum, @topic), notice: '投稿を更新しました。'
    else
      flash.now[:alert] = build_error_message(@post)
      render :edit, status: :unprocessable_entity
    end
  end

  private

  # フォーラムとトピックを取得
  #
  # フォーラムIDとトピックIDから関連データを取得
  #
  # インスタンス変数:
  #   @forum - 取得したフォーラムオブジェクト
  #   @topic - 取得したトピックオブジェクト
  #
  # セキュリティ:
  #   - @forum.topics から取得することで、他のフォーラムのトピックにはアクセス不可
  def set_forum_and_topic
    @forum = Forum.find(params[:forum_id])
    @topic = @forum.topics.find(params[:topic_id])
  rescue ActiveRecord::RecordNotFound => e
    handle_record_not_found(e)
  end

  # 投稿を取得
  #
  # トピック内の投稿を取得
  #
  # インスタンス変数:
  #   @post - 取得した投稿オブジェクト
  #
  # セキュリティ:
  #   - @topic.posts から取得することで、他のトピックの投稿にはアクセス不可
  def set_post
    @post = @topic.posts.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to forum_topic_path(@forum, @topic), alert: FLASH_MESSAGES[:post_not_found]
  end

  # ストロングパラメータ
  #
  # 許可するパラメータ:
  #   - content: 投稿内容
  def post_params
    params.require(:post).permit(:content)
  end

  # ゲストユーザーのアクセスを禁止
  #
  # ゲストユーザーは投稿機能を利用できないため、
  # ルートページへリダイレクトして警告メッセージを表示
  def forbid_guest_user!
    if current_user&.email == GUEST_USER_EMAIL
      redirect_to root_path, alert: FLASH_MESSAGES[:guest_user_forbidden]
    end
  end

  # 投稿の所有者または管理者かどうかを判定
  #
  # 編集・削除は投稿の所有者または管理者のみ可能
  # 権限がない場合はトピック詳細ページへリダイレクト
  def authorize_post_owner!
    return if admin_user?
    return if object_belongs_to_current_user?(@post)

    redirect_to forum_topic_path(@forum, @topic), alert: FLASH_MESSAGES[:unauthorized_edit]
  end

  # 投稿する権限の確認
  #
  # 投稿権限があるのは以下のユーザー:
  #   - トピックの作成者
  #   - トピックの承認済みメンバー
  #   - 管理者
  #
  # 権限がない場合はエラーメッセージを表示
  def authorize_posting!
    return if admin_user?
    return if object_belongs_to_current_user?(@topic)
    return if topic_approved_member?

    respond_to do |format|
      format.html do
        redirect_back(
          fallback_location: forum_topic_path(@forum, @topic),
          alert: FLASH_MESSAGES[:posting_forbidden]
        )
      end
      format.js do
        render js: "alert('#{FLASH_MESSAGES[:posting_forbidden]}');", status: :forbidden
      end
    end
  end

  # 管理者権限判定
  #
  # 現在のユーザーが管理者かどうかを判定
  #
  # @return [Boolean] 管理者の場合 true、それ以外 false
  def admin_user?
    current_user&.respond_to?(:admin?) && current_user.admin?
  end

  # オブジェクトの所有者判定
  #
  # さ���ざまな命名規則に対応した柔軟な所有者判定
  # creator/creator_id/user/user_id などに対応
  #
  # @param obj [ActiveRecord::Base] 判定対象のオブジェクト
  # @return [Boolean] 現在のユーザーが所有者の場合 true、それ以外 false
  #
  # 対応する属性:
  #   - creator: 関連オブジェクト
  #   - creator_id: 作成者ID
  #   - user: 関連オブジェクト
  #   - user_id: ユーザーID
  def object_belongs_to_current_user?(obj)
    return true if obj.respond_to?(:creator) && obj.creator == current_user
    return true if obj.respond_to?(:creator_id) && obj.creator_id == current_user&.id
    return true if obj.respond_to?(:user) && obj.user == current_user
    return true if obj.respond_to?(:user_id) && obj.user_id == current_user&.id

    false
  end

  # トピックに承認済みメンバーとして含まれるか判定
  #
  # 現在のユーザーがトピックの承認済みメンバーかどうかを判定
  #
  # @return [Boolean] 承認済みメンバーの場合 true、それ以外 false
  def topic_approved_member?
    @topic.respond_to?(:topic_memberships) &&
      @topic.topic_memberships.approved.exists?(user_id: current_user.id)
  end

  # トピックがロックされているか判定（現在のユーザー視点）
  #
  # トピックがロックされている場合、管理者以外は投稿不可
  #
  # @return [Boolean] ロックされていて投稿不可の場合 true、それ以外 false
  def topic_locked_for_current_user?
    @topic.locked? && !admin_user?
  end

  # 投稿を作成
  #
  # トピックに紐づく投稿を作成し、現在のユーザーを作成者として設定
  #
  # @return [Post] 作成された投稿オブジェクト（未保存）
  def build_post
    post = @topic.posts.build(post_params)
    post.creator_id = current_user.id if post.respond_to?(:creator_id)
    post
  end

  # 投稿一覧を取得（ページネーション適用）
  #
  # トピック内の投稿を作成日時の昇順で取得
  # Kaminari/WillPaginate の両方に対応
  #
  # @return [ActiveRecord::Relation] ページネーション適用済みの投稿一覧
  def fetch_paginated_posts
    posts = @topic.posts.order(created_at: :asc)

    if defined?(Kaminari)
      posts.page(params[:page]).per(PER_PAGE)
    elsif defined?(WillPaginate)
      posts.paginate(page: params[:page], per_page: PER_PAGE)
    else
      Rails.logger.warn('ページネーションライブラリ（Kaminari/WillPaginate）が見つかりません。')
      posts
    end
  end

  # ロックされたトピックへの投稿を拒否
  #
  # JS/HTML 両方に対応した共通レスポンス
  def respond_with_lock_forbidden
    respond_to do |format|
      format.html do
        redirect_to forum_topic_path(@forum, @topic), alert: FLASH_MESSAGES[:topic_locked]
      end
      format.js do
        render js: "alert('#{FLASH_MESSAGES[:topic_locked]}');", status: :forbidden
      end
    end
  end

  # 投稿作成失敗時の処理
  #
  # エラーメッセージを表示し、トピック詳細ページを再表示
  def handle_create_failure
    @posts = fetch_paginated_posts

    respond_to do |format|
      format.js { render status: :unprocessable_entity }
      format.html do
        flash.now[:alert] = build_error_message(@post, FLASH_MESSAGES[:create_failed])
        render 'public/topics/show', status: :unprocessable_entity
      end
    end
  end

  # 投稿削除失敗時の処理
  #
  # エラーメッセージを表示
  def handle_destroy_failure
    respond_to do |format|
      format.js do
        render js: "alert('#{FLASH_MESSAGES[:destroy_failed]}');", status: :internal_server_error
      end
      format.html do
        redirect_to forum_topic_path(@forum, @topic), alert: FLASH_MESSAGES[:destroy_failed]
      end
    end
  end

  # RecordNotFound 例外の処理
  #
  # フォーラムまたはトピックが見つからない場合の処理
  #
  # @param exception [ActiveRecord::RecordNotFound] 例外オブジェクト
  def handle_record_not_found(exception)
    # ログ出力（デバッグ用）
    Rails.logger.warn(
      "Record not found: " \
      "Model=#{exception.model}, " \
      "ID=#{exception.id}, " \
      "IP=#{request.remote_ip}"
    )

    # フォーラムまたはトピックのどちらが見つからないかを判定
    if exception.model == 'Forum'
      redirect_to root_path, alert: FLASH_MESSAGES[:forum_not_found]
    else
      redirect_to forums_path, alert: FLASH_MESSAGES[:topic_not_found]
    end
  end

  # バリデーションエラーメッセージを構築
  #
  # @param record [ActiveRecord::Base] エラーを持つレコード
  # @param default_message [String] デフォルトのエラーメッセージ（オプション）
  # @return [String] 整形されたエラーメッセージ
  def build_error_message(record, default_message = nil)
    return default_message || '保存できませんでした。' if record.errors.empty?

    errors = record.errors.full_messages.join(', ')
    default_message ? "#{default_message} #{errors}" : errors
  end
end