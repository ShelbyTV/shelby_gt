class AdminMailer < ActionMailer::Base
  include SendGrid

  helper :mail, :application

  def new_user_summary(new_new_users, converted_new_users, new_gt_enabled_users)
    sendgrid_category Settings::Email.new_user_summary["category"]

    # so we can distinguish these in the html.erb
    new_gt_enabled_users.map! {|u| u.user_type = 9; u }

    # combine all users into one array
    @all_new_users = new_new_users.concat(converted_new_users).concat(new_gt_enabled_users)

    mail :from => "Shelby.tv <#{Settings::Email.notification_sender}>",
      :to => "new_user_summary@shelby.tv",
      :subject => Settings::Email.new_user_summary['subject'] % { :new_users => @all_new_users.length, :date => Date.today.strftime("%m/%d/%Y") }
  end

  def weekly_email_summary(stats, time)
    sendgrid_category Settings::Email.weekly_email_summary["category"]

    @time = time
    stats.each { |name, value| instance_variable_set("@#{name}", value) }

    mail :from => "Shelby.tv <#{Settings::Email.notification_sender}>",
      :to => "weekly_email_summary@shelby.tv",
      :subject => Settings::Email.weekly_email_summary['subject'] % { :sent_emails => @sent_emails, :users_scanned => @users_scanned }
  end

  def user_stats_report(stats, time)
    sendgrid_category Settings::Email.user_stats_report["category"]

    @time = time
    @real_user_count = stats[:real_user_count]

    mail :from => "Shelby.tv <#{Settings::Email.notification_sender}>",
      :to => "henry@shelby.tv,chris@shelby.tv",
      :subject => Settings::Email.user_stats_report['subject'] % { :total => @real_user_count }
  end

end
