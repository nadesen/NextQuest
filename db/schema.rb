# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2025_11_24_114114) do

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admins", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["email"], name: "index_admins_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admins_on_reset_password_token", unique: true
  end

  create_table "follows", force: :cascade do |t|
    t.integer "follower_id", null: false
    t.integer "followed_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["followed_id"], name: "index_follows_on_followed_id"
    t.index ["follower_id", "followed_id"], name: "index_follows_on_follower_id_and_followed_id", unique: true
    t.index ["follower_id"], name: "index_follows_on_follower_id"
  end

  create_table "forums", force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.boolean "public", default: true, null: false
    t.integer "creator_id"
    t.integer "topics_count", default: 0, null: false
    t.integer "posts_count", default: 0, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["creator_id"], name: "index_forums_on_creator_id"
    t.index ["position"], name: "index_forums_on_position"
    t.index ["public"], name: "index_forums_on_public"
  end

  create_table "genres", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["name"], name: "index_genres_on_name"
  end

  create_table "likes", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "likeable_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["likeable_id"], name: "index_likes_on_likeable_id"
    t.index ["user_id", "likeable_id"], name: "index_likes_on_user_id_and_likeable_id", unique: true
    t.index ["user_id"], name: "index_likes_on_user_id"
  end

  create_table "platforms", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["name"], name: "index_platforms_on_name"
  end

  create_table "posts", force: :cascade do |t|
    t.integer "topic_id", null: false
    t.integer "creator_id", null: false
    t.text "content", null: false
    t.boolean "edited", default: false, null: false
    t.integer "likes_count", default: 0, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["creator_id"], name: "index_posts_on_creator_id"
    t.index ["topic_id"], name: "index_posts_on_topic_id"
  end

  create_table "review_comments", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "review_id", null: false
    t.text "comment"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["review_id"], name: "index_review_comments_on_review_id"
    t.index ["user_id"], name: "index_review_comments_on_user_id"
  end

  create_table "reviews", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "platform_id", null: false
    t.integer "genre_id", null: false
    t.float "rating", null: false
    t.string "title", null: false
    t.text "content", null: false
    t.string "play_time"
    t.boolean "approved", default: true, null: false
    t.integer "likes_count", default: 0, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.float "star", default: 0.0, null: false
    t.index ["genre_id"], name: "index_reviews_on_genre_id"
    t.index ["platform_id"], name: "index_reviews_on_platform_id"
    t.index ["user_id"], name: "index_reviews_on_user_id"
  end

  create_table "topic_memberships", force: :cascade do |t|
    t.integer "topic_id", null: false
    t.integer "user_id", null: false
    t.string "status", default: "pending", null: false
    t.integer "approved_by_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["approved_by_id"], name: "index_topic_memberships_on_approved_by_id"
    t.index ["status"], name: "index_topic_memberships_on_status"
    t.index ["topic_id", "user_id"], name: "index_topic_memberships_on_topic_id_and_user_id", unique: true
    t.index ["topic_id"], name: "index_topic_memberships_on_topic_id"
    t.index ["user_id"], name: "index_topic_memberships_on_user_id"
  end

  create_table "topics", force: :cascade do |t|
    t.integer "forum_id", null: false
    t.integer "creator_id", null: false
    t.string "title", null: false
    t.text "description"
    t.boolean "locked", default: false, null: false
    t.integer "posts_count", default: 0, null: false
    t.integer "views_count", default: 0, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.boolean "pinned", default: false, null: false
    t.index ["creator_id"], name: "index_topics_on_creator_id"
    t.index ["forum_id"], name: "index_topics_on_forum_id"
    t.index ["locked"], name: "index_topics_on_locked"
    t.index ["pinned"], name: "index_topics_on_pinned"
    t.index ["title"], name: "index_topics_on_title"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "nickname", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.boolean "suspended", default: false, null: false
    t.text "profile_text"
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "review_comments", "reviews"
  add_foreign_key "review_comments", "users"
end
