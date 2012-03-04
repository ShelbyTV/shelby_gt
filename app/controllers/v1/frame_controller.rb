class V1::FrameController < ApplicationController

  ##
  # Returns all frames in a roll
  #
  # [GET] /v1/roll/:id/frames.json
  # @todo FIGURE THIS OUT. BUILD IT.
  def index
    
  end
    
  ##
  # Returns one user, with the given parameters.
  #
  # [GET] /v1/frame/:id.json
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
    if @frame = Frame.find(id)
      @status =  "ok"
    else
      @status, @message = "error", "could not find that frame"
    end
  end
  
  ##
  # Creates and returns one frame, with the given parameters.
  #
  # [POST] /v1/roll/:id/frames.json
  # @todo FIGURE THIS OUT. BUILD IT.
  def create
    
  end
  
  ##
  # Updates and returns one frame, with the given parameters.
  #
  # [PUT] /v1/frame/:id.json
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
  # [DELETE] /v1/frame/:id.json
  # 
  # @param [Required, String] id The id of the frame to destroy.
  # @return [Integer] Whether request was successful or not.
  def destroy
    frame = Frame.find(params[:id])
    @status, @message = "error", "could not find that frame to destroy" unless frame
    if frame.destroy 
      @status = "ok"
    else
      @status, @message = "error", "could not destroy that frame"
    end
  end


end