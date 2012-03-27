class SharingMailer < ActionMailer::Base
  include SendGrid
  sendgrid_category Settings::Email.share_frame["category"]
  sendgrid_enable   :ganalytics, :opentrack, :clicktrack

  def share_frame(user, email_from, email_to, message, frame)
    @user= user
    @email_to = email_to
    @message = message if message
    @frame = frame if frame
    mail :from => email_from, :to => email_to, :subject => Settings::Email.share_frame['subject']
  end
end
