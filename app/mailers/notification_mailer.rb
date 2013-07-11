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

  def weekly_recommendation(user_to, dbe, friend_users=nil)
    sendgrid_category Settings::Email.weekly_recommendation["category"]

    sendgrid_ganalytics_options(:utm_source => "#{user_to.nickname}", :utm_medium => 'notification', :utm_campaign => "weekly-recommendation")

    @new_frame = dbe.frame #video info only
    @user_to   = user_to
    @new_dbe   = dbe #dashboardEntry, shelby.tv/stream/:dbe_id
    if dbe.action == DashboardEntry::ENTRY_TYPE[:video_graph_recommendation]
      @highlighted_username = dbe.src_frame.creator.nickname #frame based on video recommendation. "we recommended this because X watched/shared/liked something similar"
    elsif dbe.action == DashboardEntry::ENTRY_TYPE[:entertainment_graph_recommendation]
      @highlighted_username = friend_users.first.nickname
      @friend_users = friend_users
    end

    mail :from => "Shelby.tv <#{Settings::Email.notification_sender}>",
         :to => user_to.primary_email,
         :subject => view_context.message_subject(dbe, friend_users)
  end

end
