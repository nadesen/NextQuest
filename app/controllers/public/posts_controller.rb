class Public::PostsController < ApplicationController

  def create
    @forum = Forum.find(params[:forum_id])
    @topic = @forum.topics.find(params[:topic_id])
    @post = @topic.posts.build(post_params)
    @post.creator_id = current_user.id if @post.respond_to?(:creator_id)
    if @post.save
      redirect_to forum_topic_path(@forum, @topic), notice: '投稿しました'
    else
      @posts = @topic.posts.order(created_at: :asc).page(params[:page]) if defined?(Kaminari)
      flash.now[:alert] = '投稿に失敗しました'
      render 'public/topics/show'
    end
  end
  
end
