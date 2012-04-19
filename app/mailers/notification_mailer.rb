class NotificationMailer < ActionMailer::Base
  include SendGrid
  sendgrid_enable   :ganalytics, :opentrack, :clicktrack

  def comment_notification(user_to, user_from, conversation, message)
    sendgrid_category Settings::Email.comment_notification["category"]
    if user_to.primary_email
      @user_to = user_to
      @user_from = user_from
      @conversation = conversation
      @message = message
      #TODO: needs frame
      mail :from => Settings::Email.notification_sender, :to => user_to.primary_email, :subject => Settings::Email.comment_notification['subject']
    end
  end

  def upvote_notification(user_to, user_from, frame)
    sendgrid_category Settings::Email.upvote_notification["category"]
    if user_to.primary_email
      @user_to = user_to
      @user_from = user_from
      @frame = frame
      @permalink = "#{Settings::Email.web_url_base}/roll/#{@frame.roll.id}/frame/#{@frame.id}"
      mail :from => "notifications@shelby.tv", :to => user_to.primary_email, :subject => Settings::Email.upvote_notification['subject']
    end
  end

end
