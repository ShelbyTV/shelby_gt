class V1::FrameController < ApplicationController

  before_filter :cors_preflight_check, :user_authenticated?
  
  ##
  # Returns all frames in a roll
  #   REQUIRES AUTHENTICATION
  #
  # [GET] /v1/roll/:id/frames
  # @param [Optional, Boolean] include_children if true will return frame children
  def index
    StatsManager::StatsD.client.time(Settings::StatsNames.frame['index']) do
      @roll = Roll.find(params[:id])
      if @roll
        @include_frame_children = (params[:include_children] == "true") ? true : false
        @frames = @roll.frames.sort(:score.desc)
        @status =  200
      else
        @status, @message = 400, "could not find that roll"
        render 'v1/blank', :status => @status
      end
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
    StatsManager::StatsD.client.time(Settings::StatsNames.frame['show']) do
      if @frame = Frame.find(params[:id])
        @status =  200
        @include_frame_children = (params[:include_children] == "true") ? true : false
      else
        @status, @message = 400, "could not find that frame"
        render 'v1/blank', :status => @status
      end
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
    StatsManager::StatsD.client.time(Settings::StatsNames.frame['create']) do
      user = current_user
      roll = Roll.find(params[:id])
      frame_to_re_roll = Frame.find(params[:frame_id]) if params[:frame_id]
      if !roll
        @status, @message = 400, "could not find that roll"
        render 'v1/blank'
      elsif !frame_to_re_roll
        @status, @message = 400, "you haven't built me to do anything else yet..."
        render 'v1/blank', :status => @status
      else
        begin
          @frame = frame_to_re_roll.re_roll(user, roll)
          @frame = @frame[:frame]
          @status = 200
        rescue => e
          @status, @message = 400, "could not re_roll: #{e}"
          render 'v1/blank', :status => @status
        end
      end
    end
  end
  
  ##
  # Upvotes a frame and returns the frame back w new score
  #   REQUIRES AUTHENTICATION
  #
  # [POST] /v1/frame/:id/upvote
  # 
  # @param [Required, String] id The id of the frame
  def upvote
    StatsManager::StatsD.client.time(Settings::StatsNames.frame['upvote']) do
      if @frame = Frame.find(params[:id])
        if @frame.upvote!(current_user)
          @status = 200
          GT::UserActionManager.upvote!(current_user.id, @frame.id)
        end
        @frame.reload
      else
        @status, @message = 400, "could not find frame"
        render 'v1/blank', :status => @status
      end
    end
  end
  
  #TODO: Fill this is with what it should really be
  ##
  # Upvotes a frame and returns XXXX 
  #   REQUIRES AUTHENTICATION
  #
  # [POST] /v1/frame/:id/watched
  # 
  # @param [Required, String] id The id of the frame
  # @param [Optional, String] start_time The start_time of the action on the frame
  # @param [Optional, String] end_time The end_time of the action on the frame
  def watched
    StatsManager::StatsD.client.time(Settings::StatsNames.frame['watched']) do
      @frame = Frame.find(params[:id])
      @status, @message = 404, "BUILD ME!"
      render 'v1/blank', :status => @status
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
    StatsManager::StatsD.client.time(Settings::StatsNames.frame['destroy']) do
      if frame = Frame.find(params[:id]) and frame.destroy 
        @status = 200
      else
        @status, @message = 400, "could not find that frame to destroy" unless frame
        @status, @message = 400, "could not destroy that frame"
        render 'v1/blank', :status => @status
      end
    end
  end


end