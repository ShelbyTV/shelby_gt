require 'framer'
require 'message_manager'
require 'discussion_roll_utils'

class V1::DiscussionRollController < ApplicationController
  include GT::DiscussionRollUtils

  protect_from_forgery :except => [:create_message]
  
  before_filter :user_authenticated?, :except => [:show, :create_message]
  
  ##
  # Finds or creates a new Roll for a discussion between the given participants.
  #   AUTHENTICATION REQUIRED
  #
  # [POST] /v1/discussion_roll
  # 
  # @param [Optional, String] frame_id The id of the parent frame to post into this discussion (optional if you include video_id instead)
  # @param [Optional, String] video_id The video to post into this discussion (when there is no parent frame, above)
  # @param [Required, String] participants comma-delineated list of email address or shelby usernames (not including the current_user) participating
  # @param [Required, String] message The message current_user is sending with this video
  def create
  	#find or create a discussion roll for this group
  	@roll = find_or_create_discussion_roll_for(current_user, params[:participants])
  	
  	unless @roll
      Rails.logger.error "[DiscussionRollController#create] unable to find or create roll.  Params: #{params}"
      return render_error(404, "roll find or create failed")
    end
  	  	
	  #creates new frame (ancestor of one when given)
  	if frame = Frame.find(params[:frame_id])
  	  res = GT::Framer.re_roll(frame, current_user, @roll, true)
	  elsif video = Video.find(params[:video_id])
	    res = GT::Framer.create_frame(
	      :creator => current_user,
	      :video => video,
	      :roll => @roll,
	      :skip_dashboard_entries => true)
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

  	#sends emails to all but the poster
  	ShelbyGT_EM.next_tick { GT::NotificationManager.check_and_send_discussion_roll_notification(@roll, current_user) }
    
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
  # TODO: Return a newly created Frame if the message included a video URL,
  # otherwise just returns the updated Conversation.
  # (currently always returns an updated Conversation)
  #
  # [POST] /v1/discussion_roll/:discussion_roll_id/messages
  # 
  # @param [Optional, String] token The security token authenticating and authorizing this post
  # @param [Required, String] message The message being appended to this discussion
  def create_message
    roll = Roll.find(params[:discussion_roll_id])
    return render_error(404, "could not find roll #{params[:discussion_roll_id]}") unless roll
    unless (user_signed_in? and roll.viewable_by?(current_user)) or token_valid_for_discussion_roll?(params[:token], roll)
      return render_error(404, "you are not authorized to post to that roll")
    end
    
    return render_error(400, "you must include a message") unless params[:message]
    
    # 1) See if we have a Shelby user...
    shelby_user = current_user || user_from_token(params[:token])
    
    # 2) Create new Frame(s) or grab the last one in the Roll...
    if !(videos_in_text = find_videos_linked_in_text(params[:message])).empty?
      @new_frames = []
      videos_in_text.each do |video|
        res = GT::Framer.create_frame(
  	      :creator => shelby_user, #which may be nil
  	      :video => video,
  	      :roll => roll,
  	      :skip_dashboard_entries => true)
  	    @new_frames << res[:frame]
      end
      frame = @new_frames.last
    else    
      frame = Frame.where(:roll_id => roll.id).order(:score.desc).first
    end
    
    return render_error(404, "could not find conversation") unless frame
    @conversation = frame.conversation
    
    # 3) Post the message to the conversation (created/found above)
    if shelby_user
      @conversation.messages << GT::MessageManager.build_message(
        :user => shelby_user, 
        :public => false, 
        :origin_network => Message::ORIGIN_NETWORKS[:shelby],
        :text => CGI.unescape(params[:message]))
      poster = shelby_user
    else
      @conversation.messages << GT::MessageManager.build_message(
        :nickname => email_from_token(params[:token]).address,
        :realname => email_from_token(params[:token]).name,
        :user_image_url => nil,
        :public => false, 
        :origin_network => Message::ORIGIN_NETWORKS[:shelby],
        :text => CGI.unescape(params[:message]))
      poster = email_from_token(params[:token]).address
    end

    if @conversation.save
      #sends emails to all but the poster
    	ShelbyGT_EM.next_tick { GT::NotificationManager.check_and_send_discussion_roll_notification(roll, poster) }
    	
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