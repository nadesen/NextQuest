# 公開用フォロー機能コントローラー
#
# 機能:
#   - ユーザーのフォロー/フォロー解除
#   - フォロー中のユーザー一覧表示
#   - フォロワー一覧表示
#   - ログインユーザーのみアクセス可能
#
# 認証:
#   - authenticate_user! でログインユーザーをチェック
#   - 未ログインの場合はログインページへリダイレクト
#
# フォロー機能の設計:
#   - ユーザーモデルに follow/unfollow メソッドが定義されている想定
#   - 自分自身はフォローできない
#   - フォロー/フォロー解除後は元のページに戻る
class Public::FollowsController < ApplicationController
  # フラッシュメッセージ
  FLASH_MESSAGES = {
    followed: '%{user_name} をフォローしました。',
    unfollowed: '%{user_name} のフォローを解除しました。',
    user_not_found: 'ユーザーが見つかりませんでした。',
    cannot_follow_self: '自分自身をフォローすることはできません。'
  }.freeze

  # before_action フィルター
  before_action :authenticate_user!
  before_action :set_user

  # POST /users/:id/follow
  # ユーザーをフォロー
  #
  # 処理フロー:
  #   1. 対象ユーザーの存在確認
  #   2. 自分自身でないことを確認
  #   3. フォロー処理を実行
  #   4. 元のページにリダイレクト
  #
  # リダイレクト先:
  #   - redirect_back で元のページに戻る
  #   - フォールバック先: ユーザー詳細ページ
  def create
    # 自分自身をフォローしようとした場合
    if @user == current_user
      redirect_back(
        fallback_location: user_path(@user),
        alert: FLASH_MESSAGES[:cannot_follow_self]
      )
      return
    end

    # フォロー処理を実行
    if current_user.follow(@user)
      # 成功時: フォロー完了メッセージを表示
      user_name = @user.nickname.presence || @user.name
      notice_message = format(FLASH_MESSAGES[:followed], user_name: user_name)

      redirect_back(
        fallback_location: user_path(@user),
        notice: notice_message
      )
    else
      # 失敗時（既にフォロー済みなど）: 元のページに戻る
      redirect_back(
        fallback_location: user_path(@user),
        alert: 'フォローできませんでした。'
      )
    end
  end

  # DELETE /users/:id/unfollow
  # ユーザーのフォローを解除
  #
  # 処理フロー:
  #   1. 対象ユーザーの存在確認
  #   2. 自分自身でないことを確認
  #   3. フォロー解除処理を実行
  #   4. 元のページにリダイレクト
  #
  # リダイレクト先:
  #   - redirect_back で元のページに戻る
  #   - フォー���バック先: ユーザー詳細ページ
  def destroy
    # 自分自身のフォローを解除しようとした場合
    if @user == current_user
      redirect_back(
        fallback_location: user_path(@user),
        alert: FLASH_MESSAGES[:cannot_follow_self]
      )
      return
    end

    # フォロー解除処理を実行
    if current_user.unfollow(@user)
      # 成功時: フォロー解除完了メッセージを表示
      user_name = @user.nickname.presence || @user.name
      notice_message = format(FLASH_MESSAGES[:unfollowed], user_name: user_name)

      redirect_back(
        fallback_location: user_path(@user),
        notice: notice_message
      )
    else
      # 失敗時（既にフォローしていないなど）: 元のページに戻る
      redirect_back(
        fallback_location: user_path(@user),
        alert: 'フォロー解除できませんでした。'
      )
    end
  end

  # GET /users/:id/followings
  # フォロー中のユーザー一覧表示
  #
  # インスタンス変数:
  #   @user - 対象ユーザー（set_user で設定済み）
  #   @users - フォロー中のユーザー一覧
  #
  # ビュー:
  #   app/views/public/follows/followings.html.erb で表示
  def followings
    # @user は set_user で取得済み
    @users = @user.followings
  end

  # GET /users/:id/followers
  # フォロワー一覧表示
  #
  # インスタンス変数:
  #   @user - 対象ユーザー（set_user で設定済み）
  #   @users - フォロワー一覧
  #
  # ビュー:
  #   app/views/public/follows/followers.html.erb で表示
  def followers
    # @user は set_user で取得済み
    @users = @user.followers
  end

  private

  # ユーザーをIDから取得
  #
  # ActiveRecord::RecordNotFound が発生した場合は rescue で処理
  # 不正なIDでアクセスされた場合、ルートページへリダイレクト
  #
  # インスタンス変数:
  #   @user - 取得したユーザーオブジェクト
  #
  # 備考:
  #   - 全アクションで共通して使用
  #   - before_action で呼び出される
  def set_user
    @user = User.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: FLASH_MESSAGES[:user_not_found]
  end
end