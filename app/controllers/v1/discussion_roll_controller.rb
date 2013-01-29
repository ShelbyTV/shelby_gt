require 'framer'
require 'message_manager'
require 'discussion_roll_utils'

class V1::DiscussionRollController < ApplicationController
  include GT::DiscussionRollUtils

  protect_from_forgery :except => [:create_message]
  
  before_filter :user_authenticated?, :except => [:index, :show, :create_message]
  
  ##
  # Returns all discussion rolls accessible to the viewer.
  # If user is signed in, returns rolls based on signed in user, otherwise accessibility
  # is based on the user id (bson id or email) from the request token.
  #
  # Inserts a token with each roll returned for simple front-end access.
  #
  # [GET] /v1/discussion_roll
  #   AUTHENTICATON OR TOKEN REQUIRED
  # 
  # @param [Optional, String] token The access token for any discussion roll, roll identifier will be ignored
  def index
    @user_identifier = current_user.id.to_s if user_signed_in?
    @user_identifier = user_identifier_from_token(params[:token]) if params[:token]
    
    if @user_identifier
      @rolls = Roll.where(:discussion_roll_participants => @user_identifier).sort(:content_updated_at).all
      @status =  200
      @insert_discussion_roll_access_token = true
      render '/v1/roll/index_array'
    else
      render_error(401, "Please sign in or provide a valid token")
    end
  end
  
  ##
  # Finds or creates a new Roll for a discussion between the given participants.
  #   AUTHENTICATION REQUIRED
  #
  # [POST] /v1/discussion_roll
  # 
  # @param [Optional, String] frame_id The id of the parent frame to post into this discussion (optional if you include video_id instead)
  # @param [Optional, String] video_id The video to post into this discussion (when there is no parent frame, above)
  # @param [Optional, String] video_source_url When we don't have a proper Frame or Video, we will find_or_create the video based on this
  # @param [Required, String] participants comma-delineated list of email address or shelby usernames (not including the current_user) participating
  # @param [Required, String] message The message current_user is sending with this video
  def create
  	#find or create a discussion roll for this group
  	res = find_or_create_discussion_roll_for(current_user, params[:participants])
  	did_create = res[:did_create]
  	@roll = res[:roll]
  	
  	unless @roll
      Rails.logger.error "[DiscussionRollController#create] unable to find or create roll.  Params: #{params}"
      return render_error(404, "roll find or create failed")
    end
  	  	
	  #creates new frame (ancestor of one when given)
  	if params[:frame_id] and frame = Frame.find(params[:frame_id])
  	  res = GT::Framer.re_roll(frame, current_user, @roll, true)
	  elsif params[:video_id] and video = Video.find(params[:video_id])
	    res = GT::Framer.create_frame(
	      :creator => current_user,
	      :video => video,
	      :roll => @roll,
	      :skip_dashboard_entries => true)
    elsif params[:video_source_url] and videos_hash = GT::VideoManager.get_or_create_videos_for_url(params[:video_source_url])
      if video = videos_hash[:videos][0]
        res = GT::Framer.create_frame(
  	      :creator => current_user,
  	      :video => video,
  	      :roll => @roll,
  	      :skip_dashboard_entries => true)
      end
    end
    
    unless res and res[:frame]
      Rails.logger.error "[DiscussionRollController#create] unable to create frame for roll.  Params: #{params}"
      return render_error(404, "frame creation failed")
    end
    
    #add this message
    frame = res[:frame]
    frame.conversation.messages << GT::MessageManager.build_message(
      :user => current_user, 
      :public => false, 
      :origin_network => Message::ORIGIN_NETWORKS[:shelby],
      :text => CGI.unescape(params[:message]))
    frame.conversation.save

  	#sends discussion roll notification (handling new-convo vs. reply-to-existing) to all but the poster
  	ShelbyGT_EM.next_tick { GT::NotificationManager.send_discussion_roll_notifications(@roll, current_user, did_create) }
    
    @user_identifier = current_user.id.to_s
    @insert_discussion_roll_access_token = true
    @status =  200
    render "/v1/roll/show"
  end
  
  ##
  # Displays a discussion roll
  #   AUTHENTICATION OPTIONAL
  #
  # [GET] /v1/discussion_roll/:id
  #
  # @param [Optional, String] token The encrypted token authorizing and identifying this user, if they're not logged in
  def show
    if @roll = Roll.find(params[:id])
      
      if (user_signed_in? and @roll.viewable_by?(current_user)) or token_valid_for_discussion_roll?(params[:token], @roll)
        @status =  200
        render "/v1/roll/show"
      else
        render_error(404, "you are not authorized to see that roll")
      end
    else
      render_error(404, "that roll does not exist")
    end
  end
  
  ##
  # Appends a new message to the ongoing discussion in the given roll
  #   AUTHENTICATION OPTIONAL
  #
  # If the message includes a video URL, or videos[] is included, will return
  # an array of new Frames, one for each video, with the message appended to the
  # conversation of the last Frame.  
  # Otherwise just returns the updated Conversation.
  #
  # [POST] /v1/discussion_roll/:discussion_roll_id/messages
  # 
  # @param [Optional, String] message The message being appended to this discussion (may be nil when new video is being posted)
  # @param [Optional, String] token The security token authenticating and authorizing this post
  # @param [Optional, String] videos[] An array of URL strings to map to Shelby Videos and append to this discusison roll
  # @param [Optional, String] video_id The id of a Video document to be appended
  # @param [Optional, String] farme_id The id of a Frame document who's Video should be appended
  #
  def create_message
    roll = Roll.find(params[:discussion_roll_id])
    return render_error(404, "could not find roll #{params[:discussion_roll_id]}") unless roll
    unless (user_signed_in? and roll.viewable_by?(current_user)) or token_valid_for_discussion_roll?(params[:token], roll)
      return render_error(404, "you are not authorized to post to that roll")
    end
    
    # 1) See if we have a Shelby user...
    shelby_user = params[:token] ? user_from_token(params[:token]) : current_user
    
    # 2) Create new Frame(s) or grab the last one in the Roll...
    videos_to_append = []
    frame = Frame.find(params[:frame_id])
    videos_to_append += [frame.video].compact if frame and frame.video
    videos_to_append += [Video.find(params[:video_id])].compact if params[:video_id]
    videos_to_append += find_videos_linked_in_text(params[:message]) if params[:message]
    videos_to_append += videos_from_url_array(params[:videos]) if params[:videos]
    if !videos_to_append.empty?
      @new_frames = []
      videos_to_append.each do |video|
        res = GT::Framer.create_frame(
  	      :creator => shelby_user, #which may be nil
  	      :video => video,
  	      :roll => roll,
  	      :skip_dashboard_entries => true)
  	      
  	    # store some identifier with frame if non-shelby-user
  	    unless shelby_user
  	      res[:frame].anonymous_creator_nickname = email_from_token(params[:token]).name || email_from_token(params[:token]).address
  	      res[:frame].save
	      end
  	    @new_frames << res[:frame]
      end
      frame = @new_frames.last
      #Frames may all have same created_at; make sure the one we comment on is newest via :score
      frame.update_attribute(:score, frame.score + 0.00000001)
    else    
      frame = Frame.where(:roll_id => roll.id).order(:score.desc).first
    end
    
    # Make sure something new is getting posted (either mesasge or video)
    return render_error(400, "you must include a message or video") unless params[:message] or @new_frames
    
    return render_error(404, "could not find conversation") unless frame
    @conversation = frame.conversation
    
    # 3) Post the message (if one exists) to the conversation (created/found above)
    if shelby_user
      @conversation.messages << GT::MessageManager.build_message(
        :user => shelby_user, 
        :public => false, 
        :origin_network => Message::ORIGIN_NETWORKS[:shelby],
        :text => (params[:message] ? CGI.unescape(params[:message]) : nil))
      poster = shelby_user
    else
      @conversation.messages << GT::MessageManager.build_message(
        :nickname => email_from_token(params[:token]).address,
        :realname => email_from_token(params[:token]).name,
        :user_image_url => nil,
        :public => false, 
        :origin_network => Message::ORIGIN_NETWORKS[:shelby],
        :text => (params[:message] ? CGI.unescape(params[:message]) : nil))
      poster = email_from_token(params[:token]).address
    end

    if @conversation.save
      roll.update_attribute(:content_updated_at, Time.now)
      
      #sends discussion roll notification (only reply-to-existing flavor) to all but the poster
      ShelbyGT_EM.next_tick { GT::NotificationManager.send_discussion_roll_notifications(roll, poster, false) }
    	
      @status =  200
      # Render an array of Frames if new ones were created, or the single updated Conversation
      if @new_frames
        @include_frame_children = true
        render "/v1/frame/show_array"
      else
        render "/v1/conversation/show"
      end
    else
      Rails.logger.error "[DiscussionRollController#create_message] unable to save convo.  Params: #{params}"
      return render_error(404, "you are not authorized to post to that roll")
    end 
  end
  
end