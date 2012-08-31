require 'link_shortener'

class SharingMailer < ActionMailer::Base
  include SendGrid
  sendgrid_category Settings::Email.share_frame["category"]
  sendgrid_enable   :ganalytics, :opentrack, :clicktrack

  helper :mail

  def share_frame(user_from, email_from, email_to, message, frame)
    # user that is sharing
    utm_source = user_from.name ? URI.encode(user_from.name) : user_from.nickname
    # avatar of the user that is sharing
    utm_medium = user_from.has_shelby_avatar ? user_from.shelby_avatar_url("small") : user_from.user_image_original
    sendgrid_ganalytics_options(:utm_source => utm_source, :utm_medium => utm_medium, :utm_campaign => "email-share")
    
    @user_from = user_from
    @email_to = email_to
    @message = message ? message : frame.video.description
    @frame = frame
    @frame_permalink = frame.permalink
    
    subj = Settings::Email.share_frame['subject'] % {:sharers_name => user_from.name || user_from.nickname}
    
    mail :from => email_from, :to => email_to, :subject => subj
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
