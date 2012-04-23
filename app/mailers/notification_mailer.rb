class NotificationMailer < ActionMailer::Base
  include SendGrid
  sendgrid_enable   :ganalytics, :opentrack, :clicktrack

  def comment_notification(user_to, user_from, frame, message)
    sendgrid_category Settings::Email.comment_notification["category"]
    if user_to.primary_email
      @user_to = user_to
      @user_from = user_from
      @message = message
      @frame = frame
      
      @frame_permalink = "#{Settings::Email.web_url_base}/roll/#{@frame.roll.id}/frame/#{@frame.id}"
      @user_permalink = "#{Settings::Email.web_url_base}/user/#{@user_from.id}/personal_roll"
      mail :from => "Shelby.tv <#{Settings::Email.notification_sender}>", :to => user_to.primary_email, :subject => Settings::Email.comment_notification['subject']
      
    end
  end

  def upvote_notification(user_to, user_from, frame)
    sendgrid_category Settings::Email.upvote_notification["category"]
    if user_to.primary_email
      @user_to = user_to
      @user_from = user_from
      @frame = frame
      @permalink = "#{Settings::Email.web_url_base}/roll/#{@frame.roll.id}/frame/#{@frame.id}"
      @user_permalink = "#{Settings::Email.web_url_base}/user/#{@user_from.id}/personal_roll"
      
      mail :from => "Shelby.tv <#{Settings::Email.notification_sender}>", :to => user_to.primary_email, :subject => Settings::Email.upvote_notification['subject']
    end
  end

  def reroll_notification(old_frame, new_frame)
    sendgrid_category Settings::Email.reroll_notification["category"]

    @user_to = old_frame.creator
    @user_from = new_frame.creator

    if @user_to.primary_email
      @old_frame = old_frame
      @new_frame = new_frame
      @new_frame_permalink = "#{Settings::Email.web_url_base}/roll/#{@new_frame.roll.id}/frame/#{@new_frame.id}"
      @user_permalink = "#{Settings::Email.web_url_base}/user/#{@user_from.id}/personal_roll"
      
      mail :from => "Shelby.tv <#{Settings::Email.notification_sender}>", :to => @user_to.primary_email, :subject => Settings::Email.reroll_notification['subject']
    end
  end


end
