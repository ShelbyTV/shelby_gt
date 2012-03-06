class V1::FrameController < ApplicationController

  ##
  # Returns all frames in a roll
  #
  # [GET] /v1/roll/:id/frames.json
  def index
    @roll = Roll.find(params[:id])
    if !@roll
      @status, @message = 500, "could not find that roll"
    elsif @frames = @roll.frames
      @status =  200
    else
      @status, @message = 500, "could not find the frames from that roll"
    end
  end
    
  ##
  # Returns one frame
  #
  # [GET] /v1/frame/:id.json
  # 
  # @param [Required, String] id The id of the frame
  # @param [Optional, Boolean] include_children Include the referenced roll, video, conv, and rerolls
  def show
    if @frame = Frame.find(params[:id])
      @status =  200
      if params[:include_children]
        begin
          @roll =  @frame.role
          @video = @frame.video
          @conversation = @frame.conversation
          @rerolls = @frame.rerolls
        rescue => e
          @status, @message = 500, e
        end
      end
    else
      @status, @message = 500, "could not find that frame"
    end
  end
  
  ##
  # Creates and returns one frame, with the given parameters.
  #
  # [POST] /v1/roll/:id/frames.json
  #
  # @param [Optional, String] frame_id A frame to be re_rolled
  def create
    user = current_user
    roll = Roll.find(params[:id])
    frame_to_re_roll = Frame.find(params[:frame_id]) if params[:frame_id]
    if !roll
      @status, @message = 500, "could not find that roll"
    elsif !frame_to_re_roll
      @status, @message = 500, "you haven't built me to do anything else yet..."
    else
      begin
        @frame = frame_to_re_roll.re_roll(user, roll)
        @status = 200
      rescue => e
        @status, @message = 500, "could not re_roll: #{e}"
      end
    end
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
    @status, @message = 500, "could not find frame" unless @frame
    if @frame.update_attributes(params)
      @status = 200
    else
      @status, @message = 500, "could not update frame"
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
    @status, @message = 500, "could not find that frame to destroy" unless frame
    if frame.destroy 
      @status = 200
    else
      @status, @message = 500, "could not destroy that frame"
    end
  end


end