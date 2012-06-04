require 'link_shortener'

class SharingMailer < ActionMailer::Base
  include SendGrid
  sendgrid_category Settings::Email.share_frame["category"]
  sendgrid_enable   :ganalytics, :opentrack, :clicktrack

  helper :mail

  def share_frame(user_from, email_from, email_to, message, frame)
    @user_from = user_from
    @email_to = email_to
    @message = message ? message : frame.video.description
    @frame = frame
    params = "?gt_ref_uid=#{user_from.id.to_s}&gt_ref_email=#{email_to}&gt_ref_roll=#{frame.roll_id}"
    @frame_permalink = frame.permalink + params
    
    if @frame.roll and !@frame.roll.public?
      #this is a private roll invite
      subj = Settings::Email.share_frame['private_roll_invite_subject'] % {:inviters_name => user_from.name || user_from.nickname, :roll_title => @frame.roll.title}
    else
      subj = Settings::Email.share_frame['subject'] % {:sharers_name => user_from.name || user_from.nickname}
    end
    
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
