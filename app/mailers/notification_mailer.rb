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
    mail :from => "Shelby.tv <#{Settings::Email.notification_sender}>", 
      :to => user_to.primary_email, 
      :subject => Settings::Email.comment_notification['subject'] % { :commenters_name => (@user_from.name || @user_from.nickname), :video_title => @frame.video.title }
  end

  def upvote_notification(user_to, user_from, frame)
    sendgrid_category Settings::Email.upvote_notification["category"]
    
    @user_to = user_to
    @user_from = user_from
    @frame = frame
    @permalink = @frame.permalink
    @user_permalink = "#{Settings::Email.web_url_base}/user/#{@user_from.id}/personal_roll"
    
    mail :from => "Shelby.tv <#{Settings::Email.notification_sender}>", 
      :to => user_to.primary_email, 
      :subject => Settings::Email.upvote_notification['subject'] % { :upvoters_name => (@user_from.name || @user_from.nickname), :video_title => @frame.video.title }
  end

  def reroll_notification(old_frame, new_frame)
    sendgrid_category Settings::Email.reroll_notification["category"]

    @user_to = old_frame.creator
    @user_from = new_frame.creator

    @old_frame = old_frame
    @new_frame = new_frame
    @new_frame_permalink = @new_frame.permalink
    @user_permalink = "#{Settings::Email.web_url_base}/user/#{@user_from.id}/personal_roll"
    
    mail :from => "Shelby.tv <#{Settings::Email.notification_sender}>", 
      :to => @user_to.primary_email, 
      :subject => Settings::Email.reroll_notification['subject'] % { :re_rollers_name => (@user_from.name || @user_from.nickname), :video_title => @new_frame.video.title }
  end

  def join_roll_notification(user_to, user_from, roll)
    sendgrid_category Settings::Email.join_roll_notification["category"]

    @user_to = user_to
    @user_joined = user_from

    @roll = roll
    @roll_permalink = @roll.permalink
    @user_permalink = "#{Settings::Email.web_url_base}/user/#{@user_joined.id}/personal_roll"
    mail :from => "Shelby.tv <#{Settings::Email.notification_sender}>", 
      :to => @user_to.primary_email, 
      :subject => (Settings::Email.join_roll_notification['subject'] % { :users_name => (@user_joined.name || @user_joined.nickname), :roll_description => (@roll.public ? 'roll' : 'group roll') })
  end

end
