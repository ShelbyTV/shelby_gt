class FramesController < ApplicationConroller
  
  ##
  # Returns one user, with the given parameters.
  #
  # [GET] /frames.[format]/:id?attr_name=attr_val
  # 
  # @param [Required, String] id The id of the frame
  # @param [Optional, Boolean] include_roll Include the referenced roll
  # @param [Optional,  Boolean] include_video Include the referenced video
  # @param [Optional,  Boolean] include_post Include the referenced post
  # @param [Optional,  Boolean] include_rerolls Include the referenced rerolls
  #
  # @todo return error if id not present w/ params.has_key?(:id)
  def show
    id = params.delete(:id)
    @params = params
    @frame = Frame.find(id)
  end
  
  ##
  # Creates and returns one frame, with the given parameters.
  #
  # [POST] /frames.[format]?[argument_name=argument_val]
  # @todo FIGURE THIS OUT. BUILD IT.
  def create
    
  end
  
  ##
  # Updates and returns one frame, with the given parameters.
  #
  # [PUT] /frames.[format]/:id?attr_name=attr_val
  # 
  # @param [Required, String] id The id of the frame
  # @param [Required, String] attr The attribute(s) to update
  #
  # @todo FIGURE THIS OUT. BUILD IT.
  def update
    @frame = Frame.find(params[:id])
  end
  
  ##
  # Destroys one frame, returning Success/Failure
  #
  # [DELETE] /frames.[format]/:id
  # 
  # @param [Required, String] id The id of the frame to destroy.
  # @return [Integer] Whether request was successful or not.
  def destroy
    @frame = Frame.find(params[:id])
  end


end