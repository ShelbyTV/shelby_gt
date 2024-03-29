class DiscussionRollMailer < ActionMailer::Base
  include SendGrid
  sendgrid_enable   :opentrack, :clicktrack, :ganalytics
  
  include ActionView::Helpers::TextHelper
  helper :mail, :application
  
  # The first email sent when a conversation is started.
  # Looks very similar to subsequent reply emails, but puts an explanation of what this feature is front + center.
  #
  # Meat is: the last N elements (messages, frames) in this dicussion roll
  # 
  # see private discussion_roll_mail_setup for explanation of opts
  def on_discussion_roll_creation(opts)
    discussion_roll_mail_setup(opts)

    # for initial roll creation, always calling out video aspect
    verb, suffix = "sent", "video"
    @subject = subject_for(@poster_string_name, opts[:all_participants] - [opts[:posting_participant], opts[:receiving_participant]], verb, suffix)
    
    mail :from => "\"Shelby Mail\" <#{Settings::Email.discussion_roll['from_email']}>",
      :reply_to => "\"No Reply\" <#{Settings::Email.discussion_roll['from_email']}>",
      :to => opts[:receiving_participant_email_address], 
      :subject => @subject
  end
  
  # Meat is: the last N elements (messages, frames) in this dicussion roll
  #
  # See discussion_roll_mail_setup for explanation of opts
  def on_discussion_roll_reply(opts)
    discussion_roll_mail_setup(opts)
    
    if @last_post_video_only
      verb, suffix = "sent", "video"
    else
      verb, suffix = "replied to", nil
    end
    @subject = subject_for(@poster_string_name, opts[:all_participants] - [opts[:posting_participant], opts[:receiving_participant]], verb, suffix)
    
    mail :from => "\"Shelby Mail\" <#{Settings::Email.discussion_roll['from_email']}>",
      :reply_to => "\"No Reply\" <#{Settings::Email.discussion_roll['from_email']}>",
      :to => opts[:receiving_participant_email_address], 
      :subject => @subject
  end
  
  private
  
    # Subject must be unique and identical every time an email is sent for a given discussion roll
    # This way email clients can nicely group the emails into a conversation
    # NB: conversation_with is an array of User's or Strings (of email addresses)
    def subject_for(from_name, conversation_with, verb="sent", suffix="video")
      
      case conversation_with.count
      when 0 
        "#{from_name} #{verb} you #{suffix}"
      when 1
        "#{from_name} #{verb} you and #{nickname_for_user_or_email(conversation_with[0])} #{suffix}"
      when 2
        "#{from_name} #{verb} you, #{nickname_for_user_or_email(conversation_with[0])} and #{nickname_for_user_or_email(conversation_with[1])} #{suffix}"
      else
        others = conversation_with[0..1].map { |p| nickname_for_user_or_email(p) } .join(", ")
        "#{from_name} #{verb} you, #{others} and #{pluralize(conversation_with.count-2, 'other')} #{suffix}"
      end
    end
    
    # Sets up the variables needed by the templates (and other common setup stuff)
    #
    # Expected opts:
    #   discussion_roll: the roll itself
    #   posting_participant: the UserObject of the person who created this dicussion roll
    #   receiving_participant: the UserObject or email address (as a String) of the person to whom this email is being sent
    #   receiving_participant_email_address: the email address (as a String) of the person to whom this email is being sent
    #   all_participants: an array (of UserObjects and/or email addresses as Strings) of *everybody* participating in this conversation
    #                     this array  includes both posting_participant and receiving_participant
    #   token: the cryptographic token used in links to grant access
    def discussion_roll_mail_setup(opts)
      @roll = opts[:discussion_roll]
      @recipient_string_id = opts[:receiving_participant].is_a?(User) ? opts[:receiving_participant].id.to_s : opts[:receiving_participant]
      @poster_string_name = nickname_for_user_or_email(opts[:posting_participant])
      @token = opts[:token]
      @permalink = "http://shelby.tv/mail/#{@roll.id}?u=#{CGI.escape(@recipient_string_id)}&t=#{CGI.escape(CGI.escape(@token))}"

      sendgrid_category Settings::Email.discussion_roll["category"]
      sendgrid_ganalytics_options(:utm_source => 'discussion_roll', :utm_medium => 'notification', :utm_campaign => "roll_#{@roll.id}")
      
      # Displaying context for the most recent frame only
      most_recent_frame = Frame.where(:roll_id => @roll.id).order(:score.desc).first
      @conversation_elements = conversation_elements_for([most_recent_frame], Settings::Email.discussion_roll['max_element_count'])
      
      # get the latest message from the latest frame, use that to determine if last posting was video-only
      most_recent_message = most_recent_frame.conversation.messages[-1]
      @last_post_video_only = !most_recent_message or most_recent_message.text.blank?
    end
    
    def nickname_for_user_or_email(user_or_email_string)
      return user_or_email_string.is_a?(User) ? user_or_email_string.nickname : user_or_email_string
    end

    # Our email is going to display a summary bit of the conversation.
    # Create an array of frames and/or messages that our email template may use directly.
    #
    # expects frames array to be ordered newest to oldest
    #
    # return an array of hashes like:  [{:el_type => :frame, :el => Frame}, {:el_type => :message, :el => Message}, ...]
    # with the oldest (ie. top of email) conversation element at the top
    def conversation_elements_for(frames, max_element_count)
      els = []
      frames.each do |frame|
        # remember: messages in frame.conversation go from oldest to newest
        frame.conversation.messages.reverse.each do |msg|
          els << {:el_type => :message, :el => msg} unless msg.text.blank?
          break if els.size == max_element_count
        end
        break if els.size == max_element_count
        els << {:el_type => :frame, :el => frame}
        break if els.size == max_element_count
      end
      return els.reverse
    end
  
end
