require 'message_manager'
require 'video_manager'
require 'link_shortener'
require 'social_post_formatter'

class V1::FrameController < ApplicationController

  before_filter :user_authenticated?, :except => [:index, :show, :watched]
  skip_before_filter :verify_authenticity_token, :only => [:create]
  
  ##
  # Returns all frames in a roll
  #   AUTHENTICATION OPTIONAL
  #
  # [GET] /v1/roll/:id/frames
  # @param [Optional, Boolean] include_children if true will return frame children
  # @param [Optional, Integer] limit limit the number of frames returned, default 20
  # @param [Optional, Integer] skip the number of frames to skip, default 0
  # @param [Optional, Integer] since_id the frame to start from
  # @param [Optional, String] order which way to go: 1, -1, forward, reverse (nil ok too)
  def index
    StatsManager::StatsD.time(Settings::StatsConstants.api['frame']['index']) do
      # default params
      @limit = params[:limit] ? params[:limit] : 20
      # put an upper limit on the number of entries returned
      @limit = 20 if @limit.to_i > 20
  
      skip = params[:skip] ? params[:skip].to_i : 0
            
      if params[:roll_id]
        return render_error(404, "please specify a valid id") unless (roll_id = ensure_valid_bson_id(params[:roll_id]))
        
        @roll = Roll.find(roll_id)
        
      elsif (params[:public_roll] or params[:heart_roll])
        if user = User.find(params[:user_id]) or user = User.find_by_nickname(params[:user_id])
          if params[:public_roll]
            @roll = user.public_roll
          elsif params[:heart_roll]
            @roll = user.upvoted_roll
          end
        end
      end
      
      if @roll and @roll.viewable_by?(current_user)
        @include_frame_children = (params[:include_children] == "true") ? true : false
        # lets the view show appropriate information, eg thumbnail_url
        params[:heart_roll] = true if (user_signed_in? and @roll.id == current_user.upvoted_roll_id)

 
        # the default sort order for genius rolls is by the order field, other rolls score field
        # if needed in the future, can add a parameter so clients can specify sorting type
        if @roll.genius
          sort_by = :order.desc
        else
          sort_by = :score.desc
        end

        where_hash = { :roll_id => @roll.id }
 
        if params[:since_id]
          
          return render_error(404, "please specify a valid since_id") unless (since_id = ensure_valid_bson_id(params[:since_id]) and (since_id_frame = Frame.find(since_id)))
          
          case params[:order]
          when "1", nil, "forward"
            if @roll.genius
              where_hash[:order.lte] = since_id_frame.order 
            else
              where_hash[:score.lte] = since_id_frame.score
            end
          when "-1", "reverse"
            if @roll.genius
              where_hash[:order.gte] = since_id_frame.order 
            else
              where_hash[:score.gte] = since_id_frame.score
            end
          end
        end

        @frames = Frame.sort(sort_by).limit(@limit).skip(skip).where(where_hash).all
        
        if @frames
          #########
          # solving the N+1 problem with eager loading all children of a frame
          @entries_roll_ids = @frames.map {|f| f.roll_id }.compact.uniq
          @entries_creator_ids = @frames.map {|f| f.creator_id }.compact.uniq
          @entries_hearted_ids = @frames.map {|f| f.upvoters }.flatten.compact.uniq
          @entries_conversation_ids = @frames.map {|f| f.conversation_id }.compact.uniq
          @entries_video_ids = @frames.map {|f| f.video_id }.compact.uniq

          @rolls = Roll.find(@entries_roll_ids)
          @users = User.find((@entries_creator_ids + @entries_hearted_ids).uniq)
          @videos = Video.find(@entries_video_ids)
          @conversations = Conversation.find(@entries_conversation_ids)
          ##########
        end        
        @status =  200
      else
        render_error(404, "could not find that roll")
      end
    end
  end
    
  ##
  # Returns one frame
  #   AUTHENTICATION OPTIONAL
  #
  # [GET] /v1/frame/:id
  # 
  # @param [Required, String] id The id of the frame
  # @param [Optional, Boolean] include_children Include the referenced roll, video, conv, and rerolls
  def show
    StatsManager::StatsD.time(Settings::StatsConstants.api['frame']['show']) do
      if params[:id]
        return render_error(404, "please specify a valid id") unless (frame_id = ensure_valid_bson_id(params[:id]))
        
        @frame = Frame.find(frame_id)
        #N.B. If frame has a roll, check permissions.  If not, it has to be on your dashboard.  Checking for that is expensive b/c we don't index that way.
        # But guessing a frame is very difficult and noticeable as hacking, so we can fairly safely just return the Frame.
        if @frame 
          # make sure the frame has a roll so this doesn't get all 'so i married an axe murderer' on the consumer.
          frame_viewable_by = (@frame.roll and @frame.roll.viewable_by?(current_user))
          if (@frame.roll_id == nil or frame_viewable_by)
            @status =  200
            @include_frame_children = (params[:include_children] == "true") ? true : false
          else
            render_error(404, "that frame isn't viewable or has a bad roll")
          end
        else
          render_error(404, "could not find that frame")
        end
      else
        render_error(404, "must supply an id")
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
  #
  # Returns: The new Frame, including all children expanded.
  def create
    StatsManager::StatsD.time(Settings::StatsConstants.api['frame']['create']) do
      render_error(404, "this route is for jsonp only.") if request.get? and !params[:callback]
      
      roll = Roll.find(params[:roll_id])
      render_error(404, "could not find that roll") if !roll
      
      #on success, always want to render the full resulting Frame
      @include_frame_children = true
      
      # create frame from a video url
      if video_url = params[:url]
        frame_options = { :creator => current_user, :roll => roll }
        # get or create video from url
        frame_options[:video] = GT::VideoManager.get_or_create_videos_for_url(video_url)[:videos][0]
        
        # create message
        if params[:text]
          frame_options[:message] = GT::MessageManager.build_message(:user => current_user, :public => true, :text => CGI::unescape(params[:text]))
        end
        
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
          r = frame_options[:video] ? GT::Framer.create_frame(frame_options) : {}

          if @frame = r[:frame]
            @status = 200          
          else
            render_error(404, "something went wrong when creating that frame")
          end
          
        else
          return render_error(403, "that user cant post to that roll")
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
            render_error(403, "that user cant post to that roll")
          end
        rescue => e
          return render_error(404, "could not re_roll: #{e}")
        end
        
      else
        
        render_error(404, "you haven't built me to do anything else yet...")

      end
    end
  end
  
  ##
  # Returns success if frame is shared successfully, with the given parameters.
  #
  # [GET] /v1/frame/:frame_id/share
  # 
  # @param [Required, String] frame_id The id of the frame to share
  # @param [Required, String] destination Where the frame is being shared to (comma seperated list ok)
  # @param [Required, Escaped String] text What the status update of the post is
  def share
    StatsManager::StatsD.client.time(Settings::StatsConstants.api['frame']['share']) do
      unless params.keys.include?("destination") and params.keys.include?("text")
        return  render_error(404, "a destination and text is required to post") 
      end
      
      unless params[:destination].is_a? Array
        return  render_error(404, "destination must be an array of strings") 
      end
      
      if params[:frame_id]
        
        return render_error(404, "please specify a valid id") unless (frame_id = ensure_valid_bson_id(params[:frame_id]))
         
        frame = Frame.find(frame_id)
        # truncate text so that our link can fit fo sure
        text = params[:text]
        
        # params[:destination] is an array of destinations, 
        #  short_links will be a hash of desinations/links
        short_links = GT::LinkShortener.get_or_create_shortlinks(frame, params[:destination].join(','))
        
        resp = true
        
        params[:destination].each do |d|
          case d
          when 'twitter'
            t = GT::SocialPostFormatter.format_for_twitter(text, short_links)
            resp &= GT::SocialPoster.post_to_twitter(current_user, t)
          when 'facebook'
            t = GT::SocialPostFormatter.format_for_facebook(text, short_links)
            resp &= GT::SocialPoster.post_to_facebook(current_user, t, frame)
          when 'email'
            #NB if frame is on a private roll, this is a private roll invite.  Otherwise, it's just a Frame share
            email_addresses = params[:addresses]
            return render_error(404, "you must provide addresses") if email_addresses.blank?
            
            resp &= GT::SocialPoster.post_to_email(current_user, params[:addresses], text, frame)
          else
            return render_error(404, "we dont support that destination yet :(")
          end
          StatsManager::StatsD.increment(Settings::StatsConstants.frame['share'][d], current_user.id, 'frame_share', request)
        end
        
        if resp
          @status = 200
        else
          render_error(404, "that user cant post to that destination")
        end
        
      else
        render_error(404, "could not find that frame")
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
  # @param [Optional, Boolean] undo When "1", undoes the upvoting
  def upvote
    StatsManager::StatsD.time(Settings::StatsConstants.api['frame']['upvote']) do
      if params[:frame_id]
        
        return render_error(404, "please specify a valid id") unless (frame_id = ensure_valid_bson_id(params[:frame_id])) and @frame = Frame.find(frame_id)
        
        if params[:undo] == "1" and @frame.upvote_undo!(current_user)
          @status = 200
          GT::UserActionManager.unupvote!(current_user.id, @frame.id)
          StatsManager::StatsD.increment(Settings::StatsConstants.frame["upvote"], current_user.id, 'frame_upvote_undo', request)
          @frame.reload
        elsif @frame.upvote!(current_user)
          @status = 200
          GT::UserActionManager.upvote!(current_user.id, @frame.id)
          StatsManager::StatsD.increment(Settings::StatsConstants.frame["upvote"], current_user.id, 'frame_upvote', request)
          @frame.reload
        else
          render_error(404, "could not find frame")
        end
      else
        render_error(404, "please specify an id")
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
    StatsManager::StatsD.time(Settings::StatsConstants.api['frame']['add_to_watch_later']) do
      if params[:frame_id]
        return render_error(404, "please specify a valid id") unless (frame_id = ensure_valid_bson_id(params[:frame_id]))
        
        @frame = Frame.find(params[:frame_id])
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
    StatsManager::StatsD.time(Settings::StatsConstants.api['frame']['watched']) do
      if params[:frame_id]
        return render_error(404, "please specify a valid id") unless (frame_id = ensure_valid_bson_id(params[:frame_id]))
        
        @frame = Frame.find(frame_id)
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
    StatsManager::StatsD.time(Settings::StatsConstants.api['frame']['destroy']) do
      if params[:id]
        return render_error(404, "please specify a valid id") unless (frame_id = ensure_valid_bson_id(params[:id]))
        
        if frame = Frame.find(frame_id) and frame.destroy 
          @status = 200
        else
          render_error(404, "could not find that frame to destroy") unless frame
          render_error(404, "could not destroy that frame")
        end
      end
    end
  end


end
