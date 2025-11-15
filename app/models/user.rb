class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  has_many :review_comments, dependent: :destroy

  validates :name, presence: true, length: { maximum: 30 }
  validates :nickname, presence: true, length: { maximum: 50 }

  # 検索メソッド（searches_controller から呼び出す）
  # content: 検索語
  # method: 'perfect' | 'forward' | 'backward' | 'partial'
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
      where('nickname = :q OR name = :q OR email = :q OR profile_text = :q', q: content)
    else
      where('nickname LIKE :p OR name LIKE :p OR email LIKE :p OR profile_text LIKE :p', p: pattern)
    end
  end
end
