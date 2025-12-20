class Forum < ApplicationRecord
  has_many :topics, dependent: :destroy
  validates :title, presence: true, uniqueness: { case_sensitive: false }

  # ロックされておらず、削除もされていない実トピック数
  def actual_topics_count
    return topics.where(locked: false).count unless defined?(Topic)

    # discard gem の kept スコープがある場合
    if Topic.respond_to?(:kept)
      Topic.kept.where(forum_id: id, locked: false).count

    # deleted_at カラムによる soft delete（paranoia など）をチェック
    elsif Topic.column_names.include?('deleted_at')
      Topic.unscoped.where(forum_id: id, deleted_at: nil, locked: false).count

    # discard gem の別カラム名が使われている可能性
    elsif Topic.column_names.include?('discarded_at')
      Topic.unscoped.where(forum_id: id, discarded_at: nil, locked: false).count

    # boolean フラグ deleted がある場合
    elsif Topic.column_names.include?('deleted')
      Topic.where(forum_id: id, deleted: [false, nil], locked: false).count

    # フォールバック（削除概念がなければ locked: false のみ適用）
    else
      Topic.where(forum_id: id, locked: false).count
    end
  end
end
