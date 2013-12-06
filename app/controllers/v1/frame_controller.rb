require 'message_manager'
require 'video_manager'
require 'link_shortener'
require 'social_post_formatter'
require 'user_manager'
require 'hashtag_processor'

class V1::FrameController < ApplicationController

  before_filter :user_authenticated?, :except => [:show, :watched, :short_link, :like, :notify]
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
          last_ancestor = Frame.find(@frame.frame_ancestors.last)
          @originator = last_ancestor && last_ancestor.creator
          @status =  200
          @include_frame_children = params[:include_children]
          @upvoters = User.find(@frame.upvoters) if @include_frame_children
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

        frame_options = {}

        if is_implict_like = (current_user.watch_later_roll == roll)
          # old client trying to do a like. this should now be a light_weight share on the user's public roll
          roll = current_user.public_roll
          frame_options[:frame_type] = Frame::FRAME_TYPE[:light_weight]
        end

        frame_options[:creator] = current_user
        frame_options[:roll] = roll

        # get or create video from url
        video = frame_options[:video] = GT::VideoManager.get_or_create_videos_for_url(video_url)[:videos][0]

        # create message
        if params[:text]
          frame_options[:message] = GT::MessageManager.build_message(:user => current_user, :public => true, :text => CGI::unescape(params[:text]))
        end

        # set the action, defaults to new_bookmark_frame
        case params[:source]
        when "bookmarklet"
          frame_options[:action] = DashboardEntry::ENTRY_TYPE[:new_bookmark_frame]

          # track rolling from the bookmarklet in KissMetrics
          ShelbyGT_EM.next_tick { APIClients::KissMetrics.identify_and_record(current_user, Settings::KissMetrics.metric['roll_frame']['bookmarklet']) }
        when "extension"
          frame_options[:action] = DashboardEntry::ENTRY_TYPE[:new_bookmark_frame]

          # track rolling from the extension in KissMetrics
          ShelbyGT_EM.next_tick { APIClients::KissMetrics.identify_and_record(current_user, Settings::KissMetrics.metric['roll_frame']['extension']) }
        when "webapp"
          frame_options[:action] = DashboardEntry::ENTRY_TYPE[:new_in_app_frame]
        when nil, ""
          frame_options[:action] = DashboardEntry::ENTRY_TYPE[:new_bookmark_frame]
        else
          return render_error(404, "that action isn't cool.")
        end

        # only allow roll creation if user is authorized to access the given roll
        if roll.postable_by?(current_user)
          # and finally create the frame
          # creating dashboard entries async.
          frame_options[:async_dashboard_entries] = true

          r = frame_options[:video] ? GT::Framer.create_frame(frame_options) : {}

          if @frame = r[:frame]
            # increment like counts and record VideoLiker if this was an implicit like/ligh_weight share
            if is_implict_like
              video.like!(current_user)
            end

            # process frame message hashtags in a non-blocking manor
            ShelbyGT_EM.next_tick { GT::HashtagProcessor.process_frame_message_hashtags_for_channels(@frame) }

            if current_user.user_type != User::USER_TYPE[:service]
              if [Roll::TYPES[:special_public_real_user], Roll::TYPES[:user_public], Roll::TYPES[:global_public]].include?(roll.roll_type)
              # if this is a real human shelby user rolling to a public roll,
              # add the new frame to the community channel in a non-blocking manner
                ShelbyGT_EM.next_tick { @frame.add_to_community_channel }
              end
              # if this is a real human shelby user, send events to Google Analytics to track which
              # hashtags are being used, in a non-blocking manner
              ShelbyGT_EM.next_tick { GT::HashtagProcessor.process_frame_message_hashtags_send_to_google_analytics(@frame) }
            end

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

            # NOT sending OG action to FB for roll POST spring cleaning
            #ShelbyGT_EM.next_tick { GT::OpenGraph.send_action('roll', current_user, @frame) }

            # process frame message hashtags in a non-blocking manor
            ShelbyGT_EM.next_tick { GT::HashtagProcessor.process_frame_message_hashtags_for_channels(@frame) }

            if current_user.user_type != User::USER_TYPE[:service]
              if [Roll::TYPES[:special_public_real_user], Roll::TYPES[:user_public], Roll::TYPES[:global_public]].include?(roll.roll_type)
                # if this is a real human shelby user rolling to a public roll,
                # add the new frame to the community channel in a non-blocking manner
                ShelbyGT_EM.next_tick { @frame.add_to_community_channel }
              end
              # if this is a real human shelby user, send events to Google Analytics to track which
              # hashtags are being used, in a non-blocking manner
              ShelbyGT_EM.next_tick { GT::HashtagProcessor.process_frame_message_hashtags_send_to_google_analytics(@frame) }
            end

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

      # A Frame was rolled, track that user action
      GT::UserActionManager.frame_rolled!(current_user.id, @frame.id, @frame.video_id, @frame.roll_id)

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


  # DEPRECATED -- replaced by like
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


  # DEPRECATED -- replaced by like
  ##
  # Adds a dupe of the given Frame to the logged in users watch_later_roll and returns the dupe Frame
  #   REQUIRES AUTHENTICATION
  #
  # [POST] /v1/frame/:id/add_to_watch_later
  #
  # @param [Required, String] id The id of the frame
  #
  def add_to_watch_later
    StatsManager::StatsD.time(Settings::StatsConstants.api['frame']['add_to_watch_later']) do
        @frame = Frame.find(params[:frame_id])
        return render_error(404, "could not find frame with id #{params[:frame_id]}") unless @frame

        if @new_frame = dupe_to_watch_later(@frame)
          @status = 200
        end
    end
  end

  ##
  # Add 1 to the frame's like_count
  # If there is a user logged in, add the frame to the user's watch later roll,
  #   which internally adds to the like_count
  #
  # [PUT] /v1/frame/:id/like
  #
  # @param [Required, String] id The id of the frame
  def like
    StatsManager::StatsD.time(Settings::StatsConstants.api['frame']['like']) do
        @frame = Frame.find(params[:frame_id])
        return render_error(404, "could not find frame with id #{params[:frame_id]}") unless @frame

        if current_user
          if @new_frame = dupe_to_watch_later(@frame)
            last_ancestor = Frame.find(@frame.frame_ancestors.last)
            @originator = last_ancestor && last_ancestor.creator
            @status = 200
          end
        else
          @frame.like!
          last_ancestor = Frame.find(@frame.frame_ancestors.last)
          @originator = last_ancestor && last_ancestor.creator
          @status = 200
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
  # @param [Optional, String] start_time The start_time of the current watch span (ie. adjusts to last reported end_time)
  # @param [Optional, String] end_time The end_time of the current watch span (continually updates with progress)
  # @param [Optional, String] complete Set this param iff the viewer finished the video (and do not set <start|end>_time)
  def watched
    StatsManager::StatsD.time(Settings::StatsConstants.api['frame']['watched']) do
      if @frame = Frame.find(params[:frame_id])
        @status = 200

        # conditionally count this as a view (once per 24 hours per user)
        if params[:start_time] and params[:end_time]
          # some old users have slipped thru the cracks and are missing rolls, fix that before it's an issue
          GT::UserManager.ensure_users_special_rolls(current_user, true) unless GT::UserManager.user_has_all_special_roll_ids?(current_user) if user_signed_in?

          @view_recorded = @frame.view!(current_user)
          @frame.reload # to update view_count

          if @view_recorded and user_signed_in?
            StatsManager::StatsD.increment(Settings::StatsConstants.api['frame']['partial_watch'])
            GT::UserActionManager.view!(current_user.id, @frame.id, @frame.video_id, params[:start_time], params[:end_time])
          end
        end

        # The 'complete' action is only sent by the front end when video plays through completely
        # Currently counting it every time, which is probably/hopefully good enough
        if user_signed_in? and params[:complete]
          StatsManager::StatsD.increment(Settings::StatsConstants.api['frame']['complete_watch'])
          GT::UserActionManager.complete_view!(current_user.id, @frame.id, @frame.video_id)
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
# notifies owner of frame that something happened
#   AUTHENTICATION OPTIONAL
#
# [GET] /v1/frame/:id/notify
#
# @param [Required, String] id The id of the frame
# @param [Required, String] type What type of notification should be sent
def notify
  StatsManager::StatsD.time(Settings::StatsConstants.api['frame']['notify']) do
    return render_error(404, "must specify the type of notification to send") unless params[:type]
    if frame = Frame.find(params[:frame_id])
      @status = 200
      ShelbyGT_EM.next_tick { GT::NotificationManager.check_and_send_comment_notification(frame) if params[:type] == "comment" }
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

    def dupe_to_watch_later(frame)
      if new_frame = frame.add_to_watch_later!(current_user)
        GT::UserActionManager.like!(current_user.id, frame.id, frame.video_id)
        StatsManager::StatsD.increment(Settings::StatsConstants.frame["watch_later"])
      end
      return new_frame
    end

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
