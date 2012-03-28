require 'message_manager'
require 'video_manager'

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
  # If trying to re-roll:
  # @param [Required, String] frame_id A frame to be re_rolled
  #
  # If trying to add a frame via a url:
  # @param [Required, Escaped String] url A video url
  # @param [Optional, Escaped String] text Message text to via added to the conversation
  # @param [Optional, String] source The souce could be bookmarklet, webapp, etc
  def create
    StatsManager::StatsD.client.time(Settings::StatsNames.frame['create']) do
      roll = Roll.find(params[:roll_id])
      render_error(404, "could not find that roll") if !roll
      
      # create frame from a video url
      if video_url = params[:url]
        frame_options = { :creator => current_user, :roll => roll }
        # get or create video from url
        frame_options[:video] = GT::VideoManager.get_or_create_videos_for_url(video_url)
        
        # create message
        message_text = params[:text] ? CGI::unescape(params[:text]) : nil
        frame_options[:message] = GT::MessageManager.build_message(:creator => current_user, :public => true, :text => message_text)
        
        # set the action, defaults to new_bookmark_frame
        case params[:source]
        when "bookmark", nil, ""
          frame_options[:action] = DashboardEntry::ENTRY_TYPE[:new_bookmark_frame]
        when "webapp"
          frame_options[:action] = DashboardEntry::ENTRY_TYPE[:new_in_app_frame]
        else
          return render_error(404, "that action isn't cool.")
        end
        
        # and finally create the frame
        r = GT::Framer.create_frame(frame_options)
        
        @status = 200 if @frame = r[:frame]

        # allow for jsonp callbacks on this method for bookmarklet/extension
        render 'show', :callback => params[:callback] if params[:callback]

        else
          render_error(404, "something went wrong when creating that frame")
        end
        
      # create a new frame by re-rolling a frame from a frame_id
      elsif params[:frame_id] and ( frame_to_re_roll = Frame.find(params[:frame_id]) )
        
        begin
          @frame = frame_to_re_roll.re_roll(current_user, roll)
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