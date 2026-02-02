class TopicMembership < ApplicationRecord
  STATUSES = %w[pending approved rejected].freeze

  belongs_to :topic
  belongs_to :user
  belongs_to :approved_by, class_name: 'User', optional: true

  validates :topic_id, :user_id, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :pending,  -> { where(status: 'pending')  }
  scope :approved, -> { where(status: 'approved') }
  scope :rejected, -> { where(status: 'rejected') }

  after_create :notify_topic_owner_of_request, if: :pending?

  def pending?
    status == "pending"
  end

  private

  # 参加申請時、トピックのオーナーへ通知（未読重複防止付き）
  def notify_topic_owner_of_request
    owner =
      if topic.respond_to?(:creator) && topic.creator.present?
        topic.creator
      elsif topic.respond_to?(:user) && topic.user.present?
        topic.user
      end
    return if owner.nil? || owner.id == user_id

    unless Notification.exists?(user: owner, notifiable: topic,
                                notif_type: "topic_membership_request", read: false)
      Notification.create!(
        user: owner,
        notifiable: topic,
        notif_type: "topic_membership_request"
      )
    end
  end
end