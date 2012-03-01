class VideosController < ApplicationController  

  ##
  # Returns one video, with the given parameters.
  #
  # [GET] /videos.[format]/:id
  # 
  # @param [Required, String] id The id of the video
  # @todo return error if id not present w/ params.has_key?(:id)
  def show
    # TODO: return error if :id not present w/ params.has_key?(:id)
    id = params.delete(:id)
    @params = params
    @video = Video.find(id)
  end
  
  ##
  # Creates and returns one video, with the given parameters.
  #
  # [POST] /videos.[format]?[argument_name=argument_val]
  # @todo FIGURE THIS OUT. BUILD IT.
  def create
    
  end
  
  ##
  # Updates and returns one video, with the given parameters.
  #
  # [PUT] /video.[format]/:id?attr_name=attr_val
  # 
  # @param [Required, String] id The id of the video
  # @param [Required, String] attr The attribute(s) to update
  #
  # @todo FIGURE THIS OUT. BUILD IT.
  def update
    @video = Video.find(params[:id])
  end
  
  ##
  # Destroys one video, returning Success/Failure
  #
  # [GET] /videos.[format]/:id
  # 
  # @param [Required, String] id The id of the video to destroy.
  # @return [Integer] Whether request was successful or not.
  def destroy
    @video = Video.find(params[:id])
  end


end