class Forum < ApplicationRecord
  # フォーラムに紐づくトピック
  has_many :topics, dependent: :destroy

  # 任意: 表示順や公開フラグのバリデーションなど
  # validates :title, presence: true
end
