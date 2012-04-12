class NotificationMailer < ActionMailer::Base
  include SendGrid
  sendgrid_enable   :ganalytics, :opentrack, :clicktrack

  def comment_notification(user_to, user_from, conversation)
    sendgrid_category Settings::Email.comment_notification["category"]
    if user_to.primary_email
      @user_to = user_to
      @user_from = user_from
      @conversation = conversation
      mail :from => "notifications@shelby.tv", :to => user_to.primary_email, :subject => Settings::Email.comment_notification['subject']
    end
  end

  def upvote_notification(user_to, user_from, frame)
    sendgrid_category Settings::Email.upvote_notification["category"]
    if user_to.primary_email
      @user_to = user_to
      @user_from = user_from
      @frame = frame
      mail :from => "notifications@shelby.tv", :to => user_to.primary_email, :subject => Settings::Email.upvote_notification['subject']
    end
  end

end
