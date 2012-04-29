require 'link_shortener'

class SharingMailer < ActionMailer::Base
  include SendGrid
  sendgrid_category Settings::Email.share_frame["category"]
  sendgrid_enable   :ganalytics, :opentrack, :clicktrack

  def share_frame(user, email_from, email_to, message, frame)
    @user = user
    @email_to = email_to
    @message = message ? message : ""
    @frame = frame
    @frame_short_link = GT::LinkShortener.get_or_create_shortlinks(frame, ["email"])
    mail :from => email_from, :to => email_to, :subject => Settings::Email.share_frame['subject']
  end
end
