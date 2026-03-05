# 公開用通知管理コントローラー
#
# 機能:
#   - ユーザーへの通知一覧表示
#   - 通知の既読化（個別・一括）
#   - ログインユーザーのみアクセス可能
#   - ゲストユーザーは利用不可
#
# 認証:
#   - authenticate_user! でログインユーザーをチェック
#   - reject_guest_user! でゲストユーザーを除外
#
# 通知の種類:
#   - topic_post: トピックへの新規投稿
#   - topic_membership_request: トピック参加申請
#   - topic_membership_approved: トピック参加承認
#   - topic_membership_rejected: トピック参加拒否
#   - review_comment: レビューへのコメント
#   - followee_review: フォロー中のユーザーの新規レビュー
class Public::NotificationsController < ApplicationController
  # 定数定義
  # ページネーションの1ページあたりの表示件数
  PER_PAGE = 10

  # ゲストユーザーのメールアドレス
  GUEST_USER_EMAIL = 'guest@example.com'

  # 通知タイプの分類
  # 一覧画面でタブ分けして表示するための分類
  NOTIFICATION_TYPES = {
    topic: %w[
      topic_post
      topic_membership_request
      topic_membership_approved
      topic_membership_rejected
    ],
    review_comment: %w[review_comment],
    followee_review: %w[followee_review]
  }.freeze

  # 一括既読可能な通知タイプ（セキュリティ対策）
  BATCH_UPDATE_ALLOWED_TYPES = {
    'topic' => %w[topic_post],
    'review_comment' => %w[review_comment],
    'followee_review' => %w[followee_review]
  }.freeze

  # フラッシュメッセージ
  FLASH_MESSAGES = {
    batch_updated: '選択した通知をすべて既読にしました。',
    invalid_batch_type: 'この種類の通知は一括既読できません。',
    guest_user_rejected: 'ゲストユーザーは通知機能を利用できません。',
    notification_not_found: '通知が見つかりませんでした。'
  }.freeze

  # before_action フィルター
  before_action :authenticate_user!
  before_action :reject_guest_user!
  before_action :set_notification, only: %i[update]

  # GET /notifications
  # 通知一覧表示
  #
  # 機能:
  #   - 未読通知のみを表示
  #   - 通知タイプごとにタブ分けして表示
  #   - 各タブで個別にページネーション
  #
  # インスタンス変数:
  #   @topic_notifications - トピック関連の通知一覧
  #   @review_comment_notifications - レビューコメント通知一覧
  #   @followee_review_notifications - フォロー中ユーザーのレビュー通知一覧
  def index
    # 未読通知のみを取得（作成日時の降順）
    unread_notifications = current_user.notifications
                                       .where(read: false)
                                       .order(created_at: :desc)

    # トピック関連の通知（複数タイプを含む）
    @topic_notifications = filter_and_paginate_notifications(
      unread_notifications,
      NOTIFICATION_TYPES[:topic],
      :topic_page
    )

    # レビューコメント通知
    @review_comment_notifications = filter_and_paginate_notifications(
      unread_notifications,
      NOTIFICATION_TYPES[:review_comment],
      :review_comment_page
    )

    # フォロー中ユーザーのレビュー通知
    @followee_review_notifications = filter_and_paginate_notifications(
      unread_notifications,
      NOTIFICATION_TYPES[:followee_review],
      :followee_review_page
    )
  end

  # PATCH /notifications/:id
  # 通知を既読にする（個別）
  #
  # 処理フロー:
  #   1. 通知を既読に更新
  #   2. 通知タイプに応じた適切なページへリダイレクト
  #
  # リダイレクト先:
  #   - 通知タイプごとに異なる（redirect_to_notification メソッド参照）
  def update
    # 通知を既読に更新
    @notification.update(read: true)

    # 種類ごとに���ダイレクト先を分ける
    redirect_to_notification(@notification)
  end

  # PATCH /notifications/batch_update
  # 通知を一括既読にする
  #
  # パラメータ:
  #   - type: 一括既読対象の通知タイプ（'topic', 'review_comment', 'followee_review'）
  #
  # 処理フロー:
  #   1. 許可された通知タイプかチェック
  #   2. 該当する未読通知を一括で既読に更新
  #   3. 元のページにリダイレクト
  #
  # セキュリティ:
  #   - 許可リストで指定された通知タイプのみ一括既読可能
  def batch_update
    type = params[:type]
    notif_types = BATCH_UPDATE_ALLOWED_TYPES[type]

    if notif_types
      # 指定された種類の未読通知を一括既読に更新
      updated_count = current_user.notifications
                                  .where(read: false, notif_type: notif_types)
                                  .update_all(read: true)

      # ログ出力（監査用）
      Rails.logger.info(
        "Batch notification update: " \
        "User ID=#{current_user.id}, " \
        "Type=#{type}, " \
        "Count=#{updated_count}"
      )

      redirect_back(
        fallback_location: notifications_path,
        notice: FLASH_MESSAGES[:batch_updated]
      )
    else
      # 許可されていない通知タイプの場合
      Rails.logger.warn(
        "Invalid batch update type: " \
        "User ID=#{current_user.id}, " \
        "Type=#{type}"
      )

      redirect_back(
        fallback_location: notifications_path,
        alert: FLASH_MESSAGES[:invalid_batch_type]
      )
    end
  end

  private

  # ゲストユーザーのアクセスを拒否
  #
  # ゲストユーザーは通知機能を利用できないため、
  # ルートページへリダイレクトして警告メッセージを表示
  #
  # ゲストユーザーの判定:
  #   - メールアドレスが "guest@example.com" の場合
  def reject_guest_user!
    if current_user&.email == GUEST_USER_EMAIL
      redirect_to root_path, alert: FLASH_MESSAGES[:guest_user_rejected]
    end
  end

  # 通知をIDから取得
  #
  # 現在のユーザーの通知のみ取得可能（セキュリティ対策）
  #
  # ActiveRecord::RecordNotFound が発生した場合は rescue で処理
  # 不正なIDでアクセスされた場合、通知一覧ページへリダイレクト
  #
  # インスタンス変数:
  #   @notification - 取得した通知オブジェクト
  def set_notification
    @notification = current_user.notifications.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to notifications_path, alert: FLASH_MESSAGES[:notification_not_found]
  end

  # 通知タイプでフィルタリングしてページネート
  #
  # 通知タイプごとに絞り込み、ページネーションを適用
  # Kaminari/WillPaginate の両方に対応
  #
  # @param scope [ActiveRecord::Relation] 通知のスコープ
  # @param notif_types [String, Array<String>] フィルタする通知タイプ
  # @param page_param [Symbol] ページ番号のパラメータ名
  # @return [ActiveRecord::Relation] フィルタとページネーションが適用された通知一覧
  #
  # 備考:
  #   - 各タブで独立したページネーションを実現するため、page_param を使い分ける
  #   - notif_types が配列の場合、複数タイプをまとめて取得
  def filter_and_paginate_notifications(scope, notif_types, page_param)
    # 通知タイプでフィルタリング
    query = scope.where(notif_type: notif_types)

    # ページネーションを適用
    paginate_notifications(query, page_param)
  end

  # ページネーションを適用
  #
  # Kaminari/WillPaginate の両方に対応
  # インストールされているライブラリを自動判定して適切なメソッドを呼び出す
  #
  # @param query [ActiveRecord::Relation] ページネーション対象のクエリ
  # @param page_param [Symbol] ページ番号のパラメータ名
  # @return [ActiveRecord::Relation] ページネーションが適用されたクエリ
  def paginate_notifications(query, page_param)
    if defined?(Kaminari)
      # Kaminari が利用可能な場合
      query.page(params[page_param]).per(PER_PAGE)
    elsif defined?(WillPaginate)
      # WillPaginate が利用可能な場合
      query.paginate(page: params[page_param], per_page: PER_PAGE)
    else
      # ページネーションライブラリが未インストールの場合
      Rails.logger.warn('ページネーションライブラリ（Kaminari/WillPaginate）が見つかりません。')
      query.limit(PER_PAGE)
    end
  end

  # 各通知タイプに応じた遷移を統一的に処理
  #
  # 通知の種類に応じて適切なページへリダイレクト
  # どの分岐にも当てはまらない場合は通知一覧へ戻る
  #
  # @param notification [Notification] リダイレクト対象の通知
  #
  # リダイレクト先:
  #   - topic_membership_approved/rejected: トピック詳細ページ
  #   - topic_post: トピック詳細ページ
  #   - review_comment: レビュー詳細ページ
  #   - followee_review: レビュー詳細ページ
  #   - topic_membership_request: トピックメンバー管理ページ
  def redirect_to_notification(notification)
    case notification.notif_type
    when 'topic_membership_approved', 'topic_membership_rejected'
      redirect_to_topic_from_membership(notification)

    when 'topic_post'
      redirect_to_topic_from_post(notification)

    when 'review_comment'
      redirect_to_review_from_comment(notification)

    when 'followee_review'
      redirect_to_review(notification)

    when 'topic_membership_request'
      redirect_to_topic_members(notification)

    else
      # 未知の通知タイプの場合は警告ログを出力
      Rails.logger.warn(
        "Unknown notification type: " \
        "ID=#{notification.id}, " \
        "Type=#{notification.notif_type}"
      )
      redirect_back(fallback_location: notifications_path)
    end
  end

  # トピックメンバーシップ通知からトピック詳細へリダイレクト
  #
  # @param notification [Notification] 通知オブジェクト
  def redirect_to_topic_from_membership(notification)
    topic_membership = notification.notifiable
    topic = topic_membership&.topic if topic_membership.respond_to?(:topic)
    forum = topic&.forum

    if forum && topic
      redirect_to forum_topic_path(forum, topic)
    else
      redirect_back(fallback_location: notifications_path)
    end
  end

  # トピック投稿通知からトピック詳細へリダイレクト
  #
  # @param notification [Notification] 通知オブジェクト
  def redirect_to_topic_from_post(notification)
    topic = notification.notifiable
    forum = topic&.forum

    if forum && topic
      redirect_to forum_topic_path(forum, topic)
    else
      redirect_back(fallback_location: notifications_path)
    end
  end

  # レビューコメント通知からレビュー詳細へリダイレクト
  #
  # @param notification [Notification] 通知オブジェクト
  def redirect_to_review_from_comment(notification)
    comment = notification.notifiable
    review = comment&.review if comment&.respond_to?(:review)

    if review
      redirect_to review_path(review)
    else
      redirect_back(fallback_location: notifications_path)
    end
  end

  # レビュー通知からレビュー詳細へリダイレクト
  #
  # @param notification [Notification] 通知オブジェクト
  def redirect_to_review(notification)
    review = notification.notifiable

    if review
      redirect_to review_path(review)
    else
      redirect_back(fallback_location: notifications_path)
    end
  end

  # トピック参加申請通知からメンバー管理ページへリダイレクト
  #
  # @param notification [Notification] 通知オブジェクト
  def redirect_to_topic_members(notification)
    topic = notification.notifiable
    forum = topic&.forum

    if forum && topic
      redirect_to forum_topic_topic_members_path(forum, topic)
    else
      redirect_back(fallback_location: notifications_path)
    end
  end
end