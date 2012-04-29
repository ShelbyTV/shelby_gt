class SharingMailer < ActionMailer::Base
  include SendGrid
  sendgrid_category Settings::Email.share_frame["category"]
  sendgrid_enable   :ganalytics, :opentrack, :clicktrack

  helper :mail

  def share_frame(user_from, email_from, email_to, message, frame)
    @user_from = user_from
    @email_to = email_to
    @message = message if message
    @frame = frame if frame
    mail :from => email_from, :to => email_to, :subject => Settings::Email.share_frame['subject']
  end

=begin
  def share_roll(user_from, email_from, email_to, message, roll)
    @user_from = user_from
    @email_to = email_to
    @message = message if message
    @frame = roll if roll
    mail :from => email_from, :to => email_to, :subject => Settings::Email.share_frame['subject']
  end
=end

end
