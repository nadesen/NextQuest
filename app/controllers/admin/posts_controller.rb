# 管理者用投稿管理コントローラー
#
# 機能:
#   - フォーラム投稿の一覧表示、詳細表示、更新、削除
#   - 管理者のみアクセス可能
#
# 認証:
#   - authenticate_admin! で管理者権限をチェック
#   - 非管理者は ApplicationController でリダイレクト処理
#
# 投稿とは:
#   - フォーラムのトピック内での各ユーザーの投稿内容を管理
#   - 不適切な投稿の編集・削除を行う
class Admin::PostsController < ApplicationController
  # 定数定義
  # ページネーションの1ページあたりの表示件数
  PER_PAGE = 20

  # フラッシュメッセージ
  FLASH_MESSAGES = {
    updated: '投稿を更新しました。',
    destroyed: '投稿を削除しました。',
    not_found: '投稿が見つかりませんでした。'
  }.freeze

  # before_action フィルター
  before_action :authenticate_admin!
  before_action :set_post, only: %i[show update destroy]

  # GET /admin/posts
  # 投稿一覧表示
  #
  # 並び順: 作成日時の降順（新しい投稿が上）
  # 関連データ: topic（所属トピック）、creator（投稿者）を事前読み込み（N+1問題対策）
  # ページネーション: 必要に応じて有効化可能
  def index
    @posts = Post.includes(:topic, :creator)
                 .order(created_at: :desc)
                 .page(params[:page])
                 .per(PER_PAGE)
  end

  # GET /admin/posts/:id
  # 投稿詳細表示
  #
  # @post は set_post で設定済み
  # 投稿内容の確認、編集フォームを表示
  def show
    # @post は set_post で取得済み
    # 関連データも必要に応じて読み込む
    @topic = @post.topic
    @creator = @post.creator
  end

  # PATCH/PUT /admin/posts/:id
  # 投稿を更新
  #
  # 成功時: 投稿詳細ページへリダイレクト
  # 失敗時: 詳細ページ（編集フォーム）を再表示
  #
  # 更新可能な属性:
  #   - content: 投稿内容（不適切な表現を修正など）
  #   - edited: 編集フラグ（管理者による編集を明示）
  def update
    if @post.update(post_params)
      redirect_to admin_post_path(@post), notice: FLASH_MESSAGES[:updated]
    else
      # バリデーションエラー時は show テンプレートを再表示
      flash.now[:alert] = build_error_message(@post)
      @topic = @post.topic
      @creator = @post.creator
      render :show, status: :unprocessable_entity
    end
  end

  # DELETE /admin/posts/:id
  # 投稿を削除
  #
  # 削除後のリダイレクト先:
  #   - トピックが存在する場合: そのトピックの詳細ページ
  #   - トピックが存在しない場合: 投稿一覧ページ
  #
  # ユースケース:
  #   - トピック詳細画面から削除操作を行うことが多い想定
  #   - 削除後は元のトピックに戻ることでスムーズな管理が可能
  def destroy
    # リダイレクト先決定のため、削除前にトピックを保持
    topic = @post.topic

    if @post.destroy
      # トピックが存在する場合はトピック詳細に戻る
      if topic.present?
        redirect_to admin_topic_path(topic), notice: FLASH_MESSAGES[:destroyed]
      else
        # トピックが存在しない場合は投稿一覧に戻る
        redirect_to admin_posts_path, notice: FLASH_MESSAGES[:destroyed]
      end
    else
      # 削除に失敗した場合（外部キー制約など）
      flash[:alert] = "削除できませんでした: #{@post.errors.full_messages.join(', ')}"

      # 元の画面に戻る
      if topic.present?
        redirect_to admin_topic_path(topic)
      else
        redirect_to admin_posts_path
      end
    end
  end

  private

  # 投稿をIDから取得
  #
  # ActiveRecord::RecordNotFound が発生した場合は rescue で処理
  # 不正なIDでアクセスされた場合、投稿一覧ページへリダイレクト
  def set_post
    @post = Post.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_posts_path, alert: FLASH_MESSAGES[:not_found]
  end

  # ストロングパラメータ
  #
  # 管理画面で更新可能にしたい属性を許可
  #
  # 許可するパラメータ:
  #   - content: 投稿内容
  #   - edited: 編集フラグ（管理者が編集した場合に true にする）
  #
  # Mass Assignment 脆弱性を防ぐため、明示的に許可したパラメータのみ受け付ける
  def post_params
    params.require(:post).permit(:content, :edited)
  end

  # バリデーションエラーメッセージを構築
  #
  # ActiveRecord のエラーメッセージを整形してユーザーに表示
  #
  # @param record [ActiveRecord::Base] エラーを持つレコード
  # @return [String] 整形されたエラーメッセージ
  #
  # 例:
  #   build_error_message(@post)
  #   # => "保存できませんでした: 内容を入力してください"
  def build_error_message(record)
    return '保存できませんでした。' if record.errors.empty?

    "保存できませんでした: #{record.errors.full_messages.join(', ')}"
  end
end