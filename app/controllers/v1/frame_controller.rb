require 'message_manager'
require 'video_manager'

class V1::FrameController < ApplicationController

  before_filter :user_authenticated?, :except => :watched
  skip_before_filter :verify_authenticity_token, :only => [:create]
  
  ##
  # Returns all frames in a roll
  #   REQUIRES AUTHENTICATION
  #
  # [GET] /v1/roll/:id/frames
  # @param [Optional, Boolean] include_children if true will return frame children
  # @param [Optional, Integer] limit limit the number of frames returned, default 10
  # @param [Optional, Integer] skip the number of frames to skip, default 0
  def index
    StatsManager::StatsD.client.time(Settings::StatsConstants.api['frame']['index']) do
      # default params
      @limit = params[:limit] ? params[:limit] : 10
      # put an upper limit on the number of entries returned
      @limit = 20 if @limit.to_i > 20
  
      skip = params[:skip] ? params[:skip] : 0
      
      @roll = Roll.find(params[:roll_id])
      if @roll
        @include_frame_children = (params[:include_children] == "true") ? true : false
        @frames = @roll.frames.limit(@limit).skip(skip).sort(:score.desc)
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
    StatsManager::StatsD.client.time(Settings::StatsConstants.api['frame']['show']) do
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
  # @param [Optional, String] source The source could be bookmarklet, webapp, etc
  def create
    StatsManager::StatsD.client.time(Settings::StatsConstants.api['frame']['create']) do
      render_error(404, "this route is for jsonp only.") if request.get? and !params[:callback]
      
      roll = Roll.find(params[:roll_id])
      render_error(404, "could not find that roll") if !roll
      
      # create frame from a video url
      if video_url = params[:url]
        frame_options = { :creator => current_user, :roll => roll }
        # get or create video from url
        frame_options[:video] = GT::VideoManager.get_or_create_videos_for_url(video_url)[0]
        
        # create message
        message_text = params[:text] ? CGI::unescape(params[:text]) : nil
        frame_options[:message] = GT::MessageManager.build_message(:creator => current_user, :public => true, :text => message_text)
        
        # set the action, defaults to new_bookmark_frame
        case params[:source]
        when "bookmark", nil, ""
          StatsManager::StatsD.increment(Settings::StatsConstants.frame["create"]["bookmarklet"], current_user.id, 'frame_create_bookmarklet', request)
          frame_options[:action] = DashboardEntry::ENTRY_TYPE[:new_bookmark_frame]
        when "extension"
          StatsManager::StatsD.increment(Settings::StatsConstants.frame["create"]["extionsion"], current_user.id, 'frame_create_extension', request)
          frame_options[:action] = DashboardEntry::ENTRY_TYPE[:new_bookmark_frame]
        when "webapp"
          StatsManager::StatsD.increment(Settings::StatsConstants.frame["create"]["webapp"], current_user.id, 'frame_create_inapp', request)
          frame_options[:action] = DashboardEntry::ENTRY_TYPE[:new_in_app_frame]
        else
          return render_error(404, "that action isn't cool.")
        end
        
        # only allow roll creation if user is authorized to access the given roll
        if roll.postable_by?(current_user)
          # and finally create the frame
          r = GT::Framer.create_frame(frame_options)

          if @frame = r[:frame]
            @status = 200          
            # allow for jsonp callbacks on this method for video radar
            render 'show', :layout => 'with_callbacks' if params[:callback]
          else
            render_error(404, "something went wrong when creating that frame")
          end
          
        else
          return render_error(401, "that user cant post to that roll")
        end
        
      # create a new frame by re-rolling a frame from a frame_id
      elsif params[:frame_id] and ( frame_to_re_roll = Frame.find(params[:frame_id]) )
        
        begin
          # only allow roll creation if user is authorized to access the given roll
          if roll.postable_by?(current_user)
            @frame = frame_to_re_roll.re_roll(current_user, roll)
            @frame = @frame[:frame]
            StatsManager::StatsD.increment(Settings::StatsConstants.frame['re_roll'], current_user.id, 'frame_re_roll', request)
            @status = 200
          else
            render_error(401, "that user cant post to that roll")
          end
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
    StatsManager::StatsD.client.time(Settings::StatsConstants.api['frame']['upvote']) do
      if @frame = Frame.find(params[:frame_id])
        if @frame.upvote!(current_user)
          @status = 200
          GT::UserActionManager.upvote!(current_user.id, @frame.id)
          StatsManager::StatsD.increment(Settings::StatsConstants.frame["upvote"], current_user.id, 'frame_upvote', request)
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
    StatsManager::StatsD.client.time(Settings::StatsConstants.api['frame']['add_to_watch_later']) do
      if @frame = Frame.find(params[:frame_id])
        if @new_frame = @frame.add_to_watch_later!(current_user)
          @status = 200
          GT::UserActionManager.watch_later!(current_user.id, @frame.id)
          StatsManager::StatsD.increment(Settings::StatsConstants.frame["watch_later"], current_user.id, 'frame_watch_later', request)
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
    StatsManager::StatsD.client.time(Settings::StatsConstants.api['frame']['watched']) do
      if @frame = Frame.find(params[:frame_id])
        @status = 200
        
        #conditionally count this as a view (once per 24 hours per user)
        if current_user
          @new_frame = @frame.view!(current_user)
          @frame.reload # to update view_count
        end

        if params[:start_time] and params[:end_time]
          GT::UserActionManager.view!(current_user ? current_user.id : nil, @frame.id, params[:start_time].to_i, params[:end_time].to_i)
          StatsManager::StatsD.increment(Settings::StatsConstants.frame["watch"], current_user ? current_user.id : nil , 'frame_watch', request)
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
    StatsManager::StatsD.client.time(Settings::StatsConstants.api['frame']['destroy']) do
      if frame = Frame.find(params[:id]) and frame.destroy 
        @status = 200
      else
        render_error(404, "could not find that frame to destroy") unless frame
        render_error(404, "could not destroy that frame")
      end
    end
  end


end