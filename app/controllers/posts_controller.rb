class PostsController < ApplicationController  

  ##
  # Returns one post, with the given parameters.
  #
  # [GET] /posts.[format]/:id
  # 
  # @param [Required, String] id The id of the post
  # @todo return error if id not present w/ params.has_key?(:id)
  def show
    id = params.delete(:id)
    @params = params
    @post = Post.find(id)
  end
  
  ##
  # Creates and returns one post, with the given parameters.
  #
  # [POST] /posts.[format]?[argument_name=argument_val]
  # @todo FIGURE THIS OUT. BUILD IT.
  def create
    
  end
  
  ##
  # Updates and returns one post, with the given parameters.
  #
  # [PUT] /posts.[format]/:id?attr_name=attr_val
  # 
  # @param [Required, String] id The id of the post
  # @param [Required, String] attr The attribute(s) to update
  #
  # @todo FIGURE THIS OUT. BUILD IT.
  def update
    @post = Post.find(params[:id])
  end
  
  ##
  # Destroys one post, returning Success/Failure
  #
  # [GET] /posts.[format]/:id
  # 
  # @param [Required, String] id The id of the post to destroy.
  # @return [Integer] Whether request was successful or not.
  def destroy
    @post = Post.find(params[:id])
    if @post.destroy
      @success = 1
    else
      @error = 1
    end
  end

end