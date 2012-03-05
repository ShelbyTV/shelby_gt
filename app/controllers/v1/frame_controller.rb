class V1::FrameController < ApplicationController

  ##
  # Returns all frames in a roll
  #
  # [GET] /v1/roll/:id/frames.json
  def index
    roll = Roll.find(params[:id])
    @status, @message = "error", "could not find that roll" unless roll
    if @frames = roll.frames
      @status =  "ok"
    else
      @status, @message = "error", "could not find the frames from that roll"
    end
  end
    
  ##
  # Returns one user, with the given parameters.
  #
  # [GET] /v1/frame/:id.json
  # 
  # @param [Required, String] id The id of the frame
  # @param [Optional, Boolean] include_children Include the referenced roll, video, conv, and rerolls
  def show
    if @frame = Frame.find(params[:id])
      @status =  "ok"
      if params[:include_children]
        @roll =  @frame.role
        @video = @frame.video
        @conversation = @frame.conversation
        @rerolls = @frame.rerolls
      end
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
  def update
    id = params.delete(:id)
    @frame = Frame.find(id)
    @status, @message = "error", "could not find frame" unless @frame
    if @frame.update_attributes(params)
      @status = "ok"
    else
      @status, @message = "error", "could not update frame"
    end
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