class TopicMembership < ApplicationRecord
  STATUSES = %w[pending approved rejected].freeze

  belongs_to :topic
  belongs_to :user
  belongs_to :approved_by, class_name: 'User', optional: true

  validates :topic_id, :user_id, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: 'pending') }
  scope :approved, -> { where(status: 'approved') }
  scope :rejected, -> { where(status: 'rejected') }

  after_create :notify_topic_owner_of_request, if: :pending?

  def pending?
    status == "pending"
  end

  private

  def notify_topic_owner_of_request
    # トピックオーナーを特定
    owner =
      if topic.respond_to?(:creator) && topic.creator.present?
        topic.creator
      elsif topic.respond_to?(:user) && topic.user.present?
        topic.user
      else
        nil
      end
  
    return if owner.nil? || owner.id == user_id # 自分自身には通知不要
  
    # すでに未読の同種通知があれば新規作成しない
    unless Notification.exists?(
      user: owner,
      notifiable: topic,
      notif_type: "topic_membership_request",
      read: false
    )
      Notification.create!(
        user: owner,
        notifiable: topic,
        notif_type: "topic_membership_request"
      )
    end
  end

end