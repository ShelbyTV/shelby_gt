class DiscussionRollMailer < ActionMailer::Base
  include SendGrid
  sendgrid_enable   :opentrack, :clicktrack, :ganalytics
  
  helper :mail, :application

  # conversation_with is the array of Users and/or email addresses not including recipient.
  #   ie. [User1, "email1@gmail.com", User2, User3, "email2@gmail.com", ...]
  # token is used to authenticate and authorize users when viewing and posting messages to this discussion roll
  def state_of_discussion_roll(roll, email_to, conversation_with, token)
    sendgrid_category Settings::Email.discussion_roll["category"]
    sendgrid_ganalytics_options(:utm_source => 'discussion_roll', :utm_medium => 'notification', :utm_campaign => "roll_#{roll.id}")
    
    @token = token
    
    mail :from => Settings::Email.discussion_roll['from'], 
      :to => email_to, 
      :subject => subject_for(conversation_with)
  end
  
  private
  
    def subject_for(conversation_with)
      # Subject must be unique and identical every time an email is sent for a given discussion roll
      # This way email clients can nicely group the emails into a conversation
      conversation_with.map { |p| p.is_a?(User) ? p.nickname : p } .join(", ") + " -- Video Conversation"
    end
  
end
