class NotificationMailer < ActionMailer::Base
  include SendGrid
  sendgrid_enable   :opentrack, :clicktrack, :ganalytics
  
  helper :mail

  def comment_notification(user_to, user_from, frame, message)
    sendgrid_category Settings::Email.comment_notification["category"]

    @user_to = user_to
    @user_from = user_from
    @message = message
    @frame = frame
    
    @frame_permalink = @frame.permalink
    @user_permalink = "#{Settings::Email.web_url_base}/user/#{@user_from.id}/personal_roll"
    mail :from => "Shelby.tv <#{Settings::Email.notification_sender}>", :to => user_to.primary_email, :subject => Settings::Email.comment_notification['subject']
  end

  def upvote_notification(user_to, user_from, frame)
    sendgrid_category Settings::Email.upvote_notification["category"]
    
    @user_to = user_to
    @user_from = user_from
    @frame = frame
    @permalink = @frame.permalink
    @user_permalink = "#{Settings::Email.web_url_base}/user/#{@user_from.id}/personal_roll"
    
    mail :from => "Shelby.tv <#{Settings::Email.notification_sender}>", :to => user_to.primary_email, :subject => Settings::Email.upvote_notification['subject']
  end

  def reroll_notification(old_frame, new_frame)
    sendgrid_category Settings::Email.reroll_notification["category"]

    @user_to = old_frame.creator
    @user_from = new_frame.creator

    @old_frame = old_frame
    @new_frame = new_frame
    @new_frame_permalink = @new_frame.permalink
    @user_permalink = "#{Settings::Email.web_url_base}/user/#{@user_from.id}/personal_roll"
    
    mail :from => "Shelby.tv <#{Settings::Email.notification_sender}>", :to => @user_to.primary_email, :subject => Settings::Email.reroll_notification['subject']
  end

  def join_roll_notification(user, roll)
    sendgrid_category Settings::Email.join_roll_notification["category"]

    @user_to = roll.creator
    @user_joined = user

    @roll = roll
    @roll_permalink = @roll.permalink
    @user_permalink = "#{Settings::Email.web_url_base}/user/#{@user_joined.id}/personal_roll"
    mail :from => "Shelby.tv <#{Settings::Email.notification_sender}>", :to => @user_to.primary_email, :subject => Settings::Email.join_roll_notification['subject']    
  end

end
