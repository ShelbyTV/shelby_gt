require 'message_manager'
require 'video_manager'
require 'link_shortener'
require 'social_post_formatter'

class V1::FrameController < ApplicationController

  before_filter :user_authenticated?, :except => [:show, :watched, :short_link]
  # Assuming we're skipping CSRF for extension... that code needs to be fixed (see https://github.com/ShelbyTV/shelby-gt-web/issues/645)
  # Skipping on watched b/c it works for logged in and logged-out users
  skip_before_filter :verify_authenticity_token, :only => [:create, :watched]
 
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
      #N.B. If frame has a roll, check permissions.  If not, it has to be on your dashboard.  Checking for that is expensive b/c we don't index that way.
      # But guessing a frame is very difficult and noticeable as hacking, so we can fairly safely just return the Frame.
      if @frame = Frame.find(params[:id])
        # make sure the frame has a roll so this doesn't get all 'so i married an axe murderer' on the consumer.
        frame_viewable_by = (@frame.roll and @frame.roll.viewable_by?(current_user))
        if (@frame.roll_id == nil or frame_viewable_by)
          @status =  200
          @include_frame_children = (params[:include_children] == "true") ? true : false
        else
          render_error(404, "that frame isn't viewable or has a bad roll")
        end
      else
        render_error(404, "could not find frame with id #{params[:id]}")
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
  # @param [Optional, Escaped String] text Message text to be added to the conversation
  #
  # If trying to add a frame via a url:
  # @param [Required, Escaped String] url A video url
  # @param [Optional, Escaped String] text Message text to be added to the conversation
  # @param [Optional, String] source The source could be bookmarklet, webapp, etc
  #
  # Returns: The new Frame, including all children expanded.
  def create
    StatsManager::StatsD.time(Settings::StatsConstants.api['frame']['create']) do
      return render_error(404, "this route is for jsonp only.") if request.get? and !params[:callback]
      
      roll = Roll.find(params[:roll_id])
      return render_error(404, "could not find that roll") unless roll
      
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
          StatsManager::StatsD.increment(Settings::StatsConstants.frame["create"]["bookmarklet"])
          frame_options[:action] = DashboardEntry::ENTRY_TYPE[:new_bookmark_frame]
        when "extension"
          StatsManager::StatsD.increment(Settings::StatsConstants.frame["create"]["extionsion"])
          frame_options[:action] = DashboardEntry::ENTRY_TYPE[:new_bookmark_frame]
        when "webapp"
          StatsManager::StatsD.increment(Settings::StatsConstants.frame["create"]["webapp"])
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
            return render_error(404, "Sorry, but something went wrong trying add that video.")
          end
          
        else
          return render_error(403, "that user cant post to that roll")
        end
        
      # create a new frame by re-rolling a frame from a frame_id
      elsif params[:frame_id] and ( frame_to_re_roll = Frame.find(params[:frame_id]) )
        
        begin
          # only allow roll creation if user is authorized to access the given roll
          if roll.postable_by?(current_user)
            #do the re rolling
            res = frame_to_re_roll.re_roll(current_user, roll)
            @frame = res[:frame]
            StatsManager::StatsD.increment(Settings::StatsConstants.frame['re_roll'])
            
            if params[:text]
              @frame.conversation.messages << GT::MessageManager.build_message(:user => current_user, :public => true, :text => CGI::unescape(params[:text]))
              @frame.conversation.save
            end
            
            # send email notification in a non-blocking manor
            ShelbyGT_EM.next_tick { GT::NotificationManager.check_and_send_reroll_notification(frame_to_re_roll, @frame) }
            # send OG action to FB
            ShelbyGT_EM.next_tick { GT::OpenGraph.send_action('roll', current_user, @frame) }
            
            @status = 200
          else
            return render_error(403, "that user cant post to that roll")
          end
        rescue => e
          return render_error(404, "could not re_roll: #{e}")
        end
        
      else
        
       return render_error(404, "failed to re-roll frame from id.")

      end
    end
  end
  
  ##
  # Returns success if frame is shared successfully, with the given parameters.
  #
  # SIDE AFFECTS:
  #   - The text will be added to the frame's conversation as a new messag
  #
  # [GET] /v1/frame/:frame_id/share
  # 
  # @param [Required, String] frame_id The id of the frame to share
  # @param [Required, String] destination Where the frame is being shared to (comma seperated list)
  # @param [Optional, String] addresses The email addresses to send to
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

        frame = Frame.find(params[:frame_id])
        return render_error(404, "could not find frame with id #{params[:frame_id]}") unless frame
        return render_error(404, "invalid destinations #{params[:destination]}") unless can_share_frame_to_destinations(params[:destination], current_user)

        frameToShare = get_linkable_entity(frame, params[:destination] == ['email'])
        return render_error(404, "no valid frame to share") unless frameToShare

        #Do the sharing in the background, hope it works (we don't want to wait for slow external API calls, like awe.sm)
        ShelbyGT_EM.next_tick { share_frame_to_destinations(frameToShare, params[:destination], params[:addresses], params[:text], current_user) }
        
        @status = 200
        
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
      @frame = Frame.find(params[:frame_id])
      return render_error(404, "could not find frame with id #{params[:frame_id]}") unless @frame
      
      if params[:undo] == "1"
        if @frame.upvote_undo!(current_user)
          @status = 200
          GT::UserActionManager.unupvote!(current_user.id, @frame.id)
          StatsManager::StatsD.increment(Settings::StatsConstants.frame["upvote"])
          @frame.reload
        else
          render_error(404, "Failed to undo upvote frame #{@frame.id}")
        end
      else
        if @frame.upvote!(current_user)
          # send OG action to FB
          ShelbyGT_EM.next_tick { GT::OpenGraph.send_action('favorite', current_user, @frame) }
          
          @status = 200
          GT::UserActionManager.upvote!(current_user.id, @frame.id)
          StatsManager::StatsD.increment(Settings::StatsConstants.frame["upvote"])
          @frame.reload
        else
          render_error(404, "Failed to upvote frame #{@frame.id}")
        end
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
        @frame = Frame.find(params[:frame_id])
        return render_error(404, "could not find frame with id #{params[:frame_id]}") unless @frame
        
        if @new_frame = @frame.add_to_watch_later!(current_user)
          @status = 200
          GT::UserActionManager.watch_later!(current_user.id, @frame.id)
          StatsManager::StatsD.increment(Settings::StatsConstants.frame["watch_later"])
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
      if @frame = Frame.find(params[:frame_id])
        @status = 200
        
        #conditionally count this as a view (once per 24 hours per user)
        if current_user
          @new_frame = @frame.view!(current_user)
          @frame.reload # to update view_count
        end

        if params[:start_time] and params[:end_time]
          GT::UserActionManager.view!(current_user ? current_user.id : nil, @frame.id, params[:start_time].to_i, params[:end_time].to_i)
          StatsManager::StatsD.increment(Settings::StatsConstants.frame["watch"])
        end
      else
        render_error(404, "could not find frame")
      end
    end
  end
  
  ##
  # gets a short link for the given frame
  #   AUTHENTICATION OPTIONAL
  #
  # [GET] /v1/frame/:id/short_link
  # 
  # @param [Required, String] id The id of the frame
  def short_link
    StatsManager::StatsD.time(Settings::StatsConstants.api['frame']['short_link']) do
      if frame = Frame.find(params[:frame_id])
        entityToShortlink = get_linkable_entity(frame, true)
        return render_error(404, "no valid entity to shortlink") unless entityToShortlink

        @status = 200
        @short_link = GT::LinkShortener.get_or_create_shortlinks(entityToShortlink, 'email', current_user)
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
      @frame = Frame.find(params[:id])

      if @frame and @frame.destroyable_by?(current_user) and @frame.destroy
        #N.B. Frame#destroy does not destroy data, but the Frame won't be returned w/ the Roll anymore (see Frame#destroy)
        @status = 200
      else
        render_error(404, "You cannot destroy that frame.")
      end
    end
  end
  
  private
 
    def get_linkable_entity(frame, fallback_to_video=false)
      # watch later roll is truly private -- we don't want anyone trying to view frames on a watch later (queue) roll
      if (!frame.roll and fallback_to_video) or (frame.roll.roll_type == Roll::TYPES[:special_watch_later]) 
        # frame should have been queued from a better roll -- TODO: revisit if/when we have more private rolls
        if frame.frame_ancestors and frame.frame_ancestors.last
          return Frame.find(frame.frame_ancestors.last)
        else
          # if there are no ancestors (probably came from bookmarklet),
          # we can optionally fall back to giving a short link to the video page
          # TODO: integrate with new overall link strategy
          return fallback_to_video ? frame.video : nil
        end
      else
        return frame
      end
    end
 
    def can_share_frame_to_destinations(destinations, user)
      (destinations-['email']).each do |dest|
        return false unless user.authentications.any? { |auth| auth.provider == dest }
      end
    end
  
    def share_frame_to_destinations(frame, destinations, email_addresses, text, user)
      #  short_links will be a hash of desinations/links
      short_links = GT::LinkShortener.get_or_create_shortlinks(frame, destinations.join(','), user)

      destinations.each do |d|
        case d
        when 'twitter'
          t = GT::SocialPostFormatter.format_for_twitter(text, short_links)
          GT::SocialPoster.post_to_twitter(user, t)
        when 'facebook'
          t = GT::SocialPostFormatter.format_for_facebook(text, short_links)
          GT::SocialPoster.post_to_facebook(user, t, frame)
        when 'email'
          # This is just a Frame share
          return render_error(404, "you must provide addresses") if email_addresses.blank?

          # save any valid addresses for future use in autocomplete
          user.store_autocomplete_info(:email, email_addresses)

          # Best effort.  For speed, not checking if send succeeds (front-end should validate eaddresses format)
          ShelbyGT_EM.next_tick { GT::SocialPoster.email_frame(user, email_addresses, text, frame) }
        else
          return render_error(404, "we dont support that destination yet :(")
        end
        StatsManager::StatsD.increment(Settings::StatsConstants.frame['share'][d])
      end
    end

end
