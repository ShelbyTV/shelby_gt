class NotificationMailer < ActionMailer::Base
  include SendGrid
  sendgrid_enable   :opentrack, :clicktrack, :ganalytics
  
  helper :mail

  def comment_notification(user_to, user_from, frame, message)
    sendgrid_category Settings::Email.comment_notification["category"]
    
    sendgrid_ganalytics_options(:utm_source => 'comment', :utm_medium => 'notification', :utm_campaign => "frame_#{frame.id.to_s}")
    
    @user_to = user_to
    @user_from = user_from
    @user_from_name = (@user_from.name || @user_from.nickname)
    @user_permalink = "#{Settings::Email.web_url_base}/user/#{@user_from.id}/personal_roll"
    
    @frame = frame
    @frame_title = @frame.video.title
    @frame_permalink = @frame.permalink_to_frame_comments

    @message = message

    mail :from => "Shelby.tv <#{Settings::Email.notification_sender}>", 
      :to => user_to.primary_email, 
      :subject => Settings::Email.comment_notification['subject'] % { :commenters_name => @user_from_name, :video_title => @frame_title }
  end

  def upvote_notification(user_to, user_from, frame)
    sendgrid_category Settings::Email.upvote_notification["category"]
    
    sendgrid_ganalytics_options(:utm_source => 'heart', :utm_medium => 'notification', :utm_campaign => "frame_#{frame.id.to_s}")
    
    
    @user_to = user_to
    @user_from = user_from
    @user_from_name = (@user_from.name || @user_from.nickname)
    @user_permalink = "#{Settings::Email.web_url_base}/user/#{@user_from.id}/personal_roll"

    @frame = frame
    @frame_title = @frame.video.title
    @frame_permalink = @frame.permalink
    
    mail :from => "Shelby.tv <#{Settings::Email.notification_sender}>", 
      :to => user_to.primary_email, 
      :subject => Settings::Email.upvote_notification['subject'] % { :upvoters_name => @user_from_name, :video_title => @frame_title }
  end

  def reroll_notification(old_frame, new_frame)
    sendgrid_category Settings::Email.reroll_notification["category"]

    sendgrid_ganalytics_options(:utm_source => 'reroll', :utm_medium => 'notification', :utm_campaign => "frame_#{old_frame.id.to_s}")


    @user_to = old_frame.creator
    @user_from = new_frame.creator
    @user_from_name = (@user_from.name || @user_from.nickname)
    @user_permalink = "#{Settings::Email.web_url_base}/user/#{@user_from.id}/personal_roll"

    @old_frame = old_frame
    @new_frame = new_frame
    @new_frame_title = @new_frame.video.title
    @new_frame_permalink = @new_frame.permalink
    
    mail :from => "Shelby.tv <#{Settings::Email.notification_sender}>", 
      :to => @user_to.primary_email, 
      :subject => Settings::Email.reroll_notification['subject'] % { :re_rollers_name => @user_from_name, :video_title => @new_frame_title }
  end

  def join_roll_notification(user_to, user_from, roll)
    sendgrid_category Settings::Email.join_roll_notification["category"]

    sendgrid_ganalytics_options(:utm_source => 'join-roll', :utm_medium => 'notification', :utm_campaign => "roll_#{roll.id.to_s}")

    @user_to = user_to
    @user_from = user_from
    @user_from_name = (@user_from.name || @user_from.nickname)
    @user_permalink = "#{Settings::Email.web_url_base}/user/#{@user_from.id}/personal_roll"

    @roll = roll
    @roll_title = @roll.title
    @roll_permalink = @roll.permalink

    mail :from => "Shelby.tv <#{Settings::Email.notification_sender}>", 
      :to => @user_to.primary_email, 
      :subject => (Settings::Email.join_roll_notification['subject'] % { :users_name => @user_from_name, :roll_title => @roll_title })
  end

end
