class V1::FrameController < ApplicationController

  before_filter :user_authenticated?, :except => :watched
  
  ##
  # Returns all frames in a roll
  #   REQUIRES AUTHENTICATION
  #
  # [GET] /v1/roll/:id/frames
  # @param [Optional, Boolean] include_children if true will return frame children
  def index
    StatsManager::StatsD.client.time(Settings::StatsNames.frame['index']) do
      @roll = Roll.find(params[:roll_id])
      if @roll
        @include_frame_children = (params[:include_children] == "true") ? true : false
        @frames = @roll.frames.sort(:score.desc)
        @status =  200
      else
        render_error(404, "could not find that roll")
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
        render_error(404, "could not find that frame")
      end
    end
  end
  
  ##
  # Creates and returns one frame, with the given parameters.
  #   REQUIRES AUTHENTICATION
  #
  # [POST] /v1/roll/:roll_id/frames
  #
  # @param [Optional, String] frame_id A frame to be re_rolled
  def create
    StatsManager::StatsD.client.time(Settings::StatsNames.frame['create']) do
      user = current_user
      roll = Roll.find(params[:roll_id])
      frame_to_re_roll = Frame.find(params[:frame_id]) if params[:frame_id]
      if !roll
        render_error(404, "could not find that roll")
      elsif frame_to_re_roll
        begin
          @frame = frame_to_re_roll.re_roll(user, roll)
          @frame = @frame[:frame]
          @status = 200
        rescue => e
          render_error(404, "could not re_roll: #{e}")
        end
      else
        render_error(404, "you haven't built me to do anything else yet...")
      end
    end
  end
  
  ##
  # Upvotes a frame and returns the frame back w new score
  #   REQUIRES AUTHENTICATION
  #
  # [POST] /v1/frame/:frame_id/upvote
  # 
  # @param [Required, String] id The id of the frame
  def upvote
    StatsManager::StatsD.client.time(Settings::StatsNames.frame['upvote']) do
      if @frame = Frame.find(params[:frame_id])
        if @frame.upvote!(current_user)
          @status = 200
          GT::UserActionManager.upvote!(current_user.id, @frame.id)
        end
        @frame.reload
      else
        render_error(404, "could not find frame")
      end
    end
  end
  
  ##
  # Adds a dupe of the given Frame to the logged in users watch_later_roll and returns the dupe Frame
  #   REQUIRES AUTHENTICATION
  #
  # [POST] /v1/frame/:id/add_to_watch_later
  # 
  # @param [Required, String] id The id of the frame
  def add_to_watch_later
    StatsManager::StatsD.client.time(Settings::StatsNames.frame['add_to_watch_later']) do
      if @frame = Frame.find(params[:frame_id])
        if @new_frame = @frame.add_to_watch_later!(current_user)
          @status = 200
          GT::UserActionManager.watch_later!(current_user.id, @frame.id)
        end
      else
        render_error(404, "could not find frame")
      end
    end
  end
  
  ##
  # For logged in user, update their viewed_roll and view_count on Frame and Video (once per 24 hours per user)
  # For logged in and non-logged in user, create a UserAction to track this portion of viewing.
  #   AUTHENTICATION OPTIONAL
  #
  # [POST] /v1/frame/:id/watched
  # 
  # @param [Required, String] id The id of the frame
  # @param [Optional, String] start_time The start_time of the action on the frame
  # @param [Optional, String] end_time The end_time of the action on the frame
  def watched
    StatsManager::StatsD.client.time(Settings::StatsNames.frame['watched']) do
      if @frame = Frame.find(params[:frame_id])
        @status = 200
        
        #conditionally count this as a view (once per 24 hours per user)
        if current_user
          @new_frame = @frame.view!(current_user)
          @frame.reload # to update view_count
        end

        if params[:start_time] and params[:end_time]
          GT::UserActionManager.view!(current_user ? current_user.id : nil, @frame.id, params[:start_time].to_i, params[:end_time].to_i)
        end
      else
        render_error(404, "could not find frame")
      end
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
        render_error(404, "could not find that frame to destroy") unless frame
        render_error(404, "could not destroy that frame")
      end
    end
  end


end