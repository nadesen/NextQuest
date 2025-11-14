class Review < ApplicationRecord
  belongs_to :user
  belongs_to :platform
  belongs_to :genre
  validates :title, presence: true
  validates :play_time, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :rating, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }
  validates :content, presence: true, length: { maximum: 2000 }
  
  def self.search_for(content, method)
    return none if content.blank?

    pattern =
      case method
      when 'perfect'
        content
      when 'forward'
        "#{sanitize_sql_like(content)}%"
      when 'backward'
        "%#{sanitize_sql_like(content)}"
      else
        "%#{sanitize_sql_like(content)}%"
      end

    if method == 'perfect'
      where('title = ? OR content = ?', content, content)
    else
      where('title LIKE ? OR content LIKE ?', pattern, pattern)
    end
  end

end
