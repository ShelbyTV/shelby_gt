class NotificationMailer < ActionMailer::Base
  include SendGrid
  sendgrid_enable   :opentrack, :clicktrack, :ganalytics

  helper :mail, :roll, :weekly_recommendation_email, :application

  def comment_notification(user_to, user_from, frame, message)
    sendgrid_category Settings::Email.comment_notification["category"]

    sendgrid_ganalytics_options(:utm_source => 'comment', :utm_medium => 'notification', :utm_campaign => "frame_#{frame.id.to_s}")

    @user_to = user_to
    @user_from = user_from
    @user_from_name = (@user_from.name || @user_from.nickname)
    @user_permalink = @user_from.permalink

    @frame = frame
    @frame_title = @frame.video.title
    @frame_permalink = @frame.permalink_to_frame_comments

    @frame_conversation_messages = (frame.conversation && frame.conversation.messages) || nil

    @message = message

    if @user_to = @frame.creator
      subject = Settings::Email.comment_notification['subject_a'] % { :commenters_name => @user_from_name, :video_title => @frame_title }
    else
      subject = Settings::Email.comment_notification['subject_b'] % { :commenters_name => @user_from_name, :video_title => @frame_title }
    end

    mail :from => "Shelby.tv <#{Settings::Email.notification_sender}>",
      :to => user_to.primary_email,
      :subject => subject
  end

  def disqus_comment_notification(frame, user_to)
    sendgrid_category Settings::Email.disqus_comment_notification["category"]

    sendgrid_ganalytics_options(:utm_source => frame.id.to_s, :utm_medium => 'disqus_comment', :utm_campaign => "notification")

    @frame = frame

    mail :from => "Shelby.tv <#{Settings::Email.notification_sender}>",
      :to => user_to.primary_email,
      :subject => Settings::Email.disqus_comment_notification['subject']
  end

  def reroll_notification(old_frame, new_frame)
    sendgrid_category Settings::Email.reroll_notification["category"]

    sendgrid_ganalytics_options(:utm_source => 'reshare', :utm_medium => 'notification', :utm_campaign => "frame_#{old_frame.id.to_s}")


    @user_to = old_frame.creator
    @user_from = new_frame.creator
    @user_from_name = (@user_from.name || @user_from.nickname)
    @user_permalink = @user_from.permalink

    @old_frame = old_frame
    @new_frame = new_frame
    @new_frame_title = @new_frame.video.title
    @new_frame_permalink = @new_frame.permalink

    mail :from => "Shelby.tv <#{Settings::Email.notification_sender}>",
      :to => @user_to.primary_email,
      :subject => Settings::Email.reroll_notification['subject'] % { :re_rollers_name => @user_from_name, :video_title => @new_frame_title }
  end

  def like_notification(user_to, frame, user_from=nil)
    sendgrid_category Settings::Email.like_notification["category"]

    sendgrid_ganalytics_options(:utm_source => 'like', :utm_medium => 'notification', :utm_campaign => "frame_#{frame.id.to_s}")


    @user_to = user_to

    if user_from
      # liked by a logged in user
      @user_from = user_from
      @user_from_name = (@user_from.name || @user_from.nickname)
      @user_permalink = @user_from.permalink
    else
      # liked anonymously by a logged out user
      @user_from_name = "Someone"
    end

    @frame = frame
    @frame_title = @frame.video.title
    @frame_permalink = @frame.permalink

    mail :from => "Shelby.tv <#{Settings::Email.notification_sender}>",
      :to => user_to.primary_email,
      :subject => Settings::Email.like_notification['subject'] % { :likers_name => @user_from_name }
  end

  def join_roll_notification(user_to, user_from, roll)
    sendgrid_category Settings::Email.join_roll_notification["category"]

    sendgrid_ganalytics_options(:utm_source => 'follow', :utm_medium => 'notification', :utm_campaign => "roll_#{roll.id.to_s}")

    @user_to = user_to
    @user_from = user_from
    @user_from_name = (@user_from.name || @user_from.nickname)
    @user_permalink = @user_from.permalink

    @roll = roll

    mail :from => "Shelby.tv <#{Settings::Email.notification_sender}>",
      :to => @user_to.primary_email,
      :subject => (Settings::Email.join_roll_notification['subject'] % { :users_name => @user_from_name})
  end

  def upvote_notification(user_to, user_from, frame)
    sendgrid_category Settings::Email.upvote_notification["category"]

    sendgrid_ganalytics_options(:utm_source => 'heart', :utm_medium => 'notification', :utm_campaign => "frame_#{frame.id.to_s}")


    @user_to = user_to
    @user_from = user_from
    @user_from_name = (@user_from.name || @user_from.nickname)
    @user_permalink = @user_from.permalink

    @frame = frame
    @frame_title = @frame.video.title
    @frame_permalink = @frame.permalink

    mail :from => "Shelby.tv <#{Settings::Email.notification_sender}>",
      :to => user_to.primary_email,
      :subject => Settings::Email.upvote_notification['subject'] % { :upvoters_name => @user_from_name, :video_title => @frame_title }
  end

  def invite_accepted_notification(user_to, user_from, roll)
    sendgrid_category Settings::Email.invite_accepted_notification["category"]

    sendgrid_ganalytics_options(:utm_source => 'invite-accepted', :utm_medium => 'notification', :utm_campaign => "roll_#{roll.id.to_s}")

    @user_to = user_to
    @user_from = user_from
    @user_from_name = (@user_from.name || @user_from.nickname)
    @user_permalink = @user_from.permalink

    @roll = roll

    mail :from => "Shelby.tv <#{Settings::Email.notification_sender}>",
      :to => @user_to.primary_email,
      :subject => (Settings::Email.invite_accepted_notification['subject'] % { :users_name => @user_from_name })
  end

  def weekly_recommendation(user_to, dbes, options=nil)
    sendgrid_category Settings::Email.weekly_recommendation["category"]

    @ab_bucket = options[:bucket] if options
    if @ab_bucket
      utm_medium = "notification-#{@ab_bucket}"
    else
      utm_medium = "notification"
    end
    sendgrid_ganalytics_options(:utm_source => "#{user_to.nickname}", :utm_medium => utm_medium, :utm_campaign => 'weekly-recommendation')

    @dbes = dbes
    @user_to = user_to

    first_name = (@user_to.name.split.first if @user_to.name) || @user_to.nickname
    subject_line = "#{first_name.titlecase}, #{view_context.message_subject(dbes).downcase}"

    mail :from => "Shelby.tv <#{Settings::Email.notification_sender}>",
         :to => user_to.primary_email,
         :subject => subject_line
  end

end
