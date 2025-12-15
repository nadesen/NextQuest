class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :notifiable, polymorphic: true

  def readable_in_batch?
    notif_type == "topic_post"
  end
end
