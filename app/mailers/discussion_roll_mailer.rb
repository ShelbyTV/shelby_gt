class DiscussionRollMailer < ActionMailer::Base
  include SendGrid
  sendgrid_enable   :opentrack, :clicktrack, :ganalytics
  
  helper :mail, :application

  # conversation_with is the array of Users and/or email addresses not including recipient.
  #   ie. [User1, "email1@gmail.com", User2, User3, "email2@gmail.com", ...]
  # token is used to authenticate and authorize users when viewing and posting messages to this discussion roll
  # recipient is the user id (as string) or email address of the recipient, as stored in Roll.discussion_roll_participants
  #
  # poster may be a User or an email address
  def state_of_discussion_roll(roll, email_to, recipient, poster, conversation_with, token)
    sendgrid_category Settings::Email.discussion_roll["category"]
    sendgrid_ganalytics_options(:utm_source => 'discussion_roll', :utm_medium => 'notification', :utm_campaign => "roll_#{roll.id}")
    
    @recipient = recipient
    @token = token
    @poster = poster
    @from_name = poster.is_a?(User) ? poster.nickname : poster
    @roll = roll
    @most_recent_frame = Frame.where(:roll_id => roll.id).order(:score.desc).first
    @message = @most_recent_frame.conversation.messages[-1]
    @permalink = "http://shelby.tv/chat/#{@roll.id}?u=#{CGI.escape(@recipient)}&t=#{CGI.escape(CGI.escape(@token))}"
    
    mail :from => Settings::Email.discussion_roll['from_email'], 
      :to => email_to, 
      :subject => subject_for(conversation_with)
  end
  
  private
  
    # Subject must be unique and identical every time an email is sent for a given discussion roll
    # This way email clients can nicely group the emails into a conversation
    def subject_for(conversation_with)
      "Shelby Chat: " + (conversation_with.map { |p| p.is_a?(User) ? p.nickname : p } .join(", "))
    end
  
end
