class Forum < ApplicationRecord
  # フォーラムに紐づくトピック
  has_many :topics, dependent: :destroy

  # 実際に「削除されていない」トピック数を返すユーティリティメソッド
  def actual_topics_count
    return topics_count.to_i unless defined?(Topic)

    # discard gem の kept スコープがある場合
    if Topic.respond_to?(:kept)
      Topic.kept.where(forum_id: id).count

    # deleted_at カラムによる soft delete（paranoia など）をチェック
    elsif Topic.column_names.include?('deleted_at')
      Topic.unscoped.where(forum_id: id).where(deleted_at: nil).count

    # discard gem の別カラム名が使われている可能性
    elsif Topic.column_names.include?('discarded_at')
      Topic.unscoped.where(forum_id: id).where(discarded_at: nil).count

    # boolean フラグ deleted がある場合
    elsif Topic.column_names.include?('deleted')
      Topic.where(forum_id: id, deleted: [false, nil]).count

    # フォールバック（削除概念がなければ通常の件数）
    else
      Topic.where(forum_id: id).count
    end
  end
end
