class Public::HomesController < ApplicationController
  def top
    @latest_topics = Topic.order(created_at: :desc).limit(5)
    @latest_reviews = Review.order(created_at: :desc).limit(5)
  end
end
