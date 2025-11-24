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
end