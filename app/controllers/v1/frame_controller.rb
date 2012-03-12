class V1::FrameController < ApplicationController

  before_filter :authenticate_user!

  ##
  # Returns all frames in a roll
  #   REQUIRES AUTHENTICATION
  #
  # [GET] /v1/roll/:id/frames
  # @param [Optional, Boolean] include_children if true will return frame children
  def index
    @roll = Roll.find(params[:id])
    if @roll
      @include_children = (params[:include_children] == "true") ? true : false
      @status =  200
    else
      @status, @message = 500, "could not find that roll"
      render 'v1/blank'
    end
  end
    
  ##
  # Returns one frame
  #   REQUIRES AUTHENTICATION
  #
  # [GET] /v1/frame/:id
  # 
  # @param [Required, String] id The id of the frame
  # @param [Optional, Boolean] include_children Include the referenced roll, video, conv, and rerolls
  def show
    if @frame = Frame.find(params[:id])
      @status =  200
      @include_frame_children = (params[:include_children] == "true") ? true : false
    else
      @status, @message = 500, "could not find that frame"
      render 'v1/blank'
    end
  end
  
  ##
  # Creates and returns one frame, with the given parameters.
  #   REQUIRES AUTHENTICATION
  #
  # [POST] /v1/roll/:id/frames
  #
  # @param [Optional, String] frame_id A frame to be re_rolled
  def create
    user = current_user
    roll = Roll.find(params[:id])
    frame_to_re_roll = Frame.find(params[:frame_id]) if params[:frame_id]
    if !roll
      @status, @message = 500, "could not find that roll"
      render 'v1/blank'
    elsif !frame_to_re_roll
      @status, @message = 500, "you haven't built me to do anything else yet..."
      render 'v1/blank'
    else
      begin
        @frame = frame_to_re_roll.re_roll(user, roll)
        @status = 200
      rescue => e
        @status, @message = 500, "could not re_roll: #{e}"
        render 'v1/blank'
      end
    end
  end
  
  ##
  # Updates and returns one frame, with the given parameters.
  #   REQUIRES AUTHENTICATION
  #
  # [PUT] /v1/frame/:id
  # 
  # @param [Required, String] id The id of the frame
  # @param [Required, String] attr The attribute(s) to update
  def update
    id = params.delete(:id)
    if @frame = Frame.find(id)
      begin 
        @frame.update_attributes!(params)
        @frame.save!
        @status = 200
      rescue => e
        @frame = nil
        @status, @message = 500, "could not update frame: #{e}"
        render 'v1/blank'
      end
    else
      @status, @message = 500, "could not find frame"
      render 'v1/blank'     
    end
  end
  
  ##
  # Destroys one frame, returning Success/Failure
  #   REQUIRES AUTHENTICATION
  #
  # [DELETE] /v1/frame/:id
  # 
  # @param [Required, String] id The id of the frame to destroy.
  # @return [Integer] Whether request was successful or not.
  def destroy
    if frame = Frame.find(params[:id]) and frame.destroy 
      @status = 200
    else
      @status, @message = 500, "could not find that frame to destroy" unless frame
      @status, @message = 500, "could not destroy that frame"
      render 'v1/blank'
    end
  end


end