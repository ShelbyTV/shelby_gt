class AdminMailer < ActionMailer::Base
  include SendGrid
  
  helper :mail

  def new_user_summary(new_new_users, converted_new_users, new_gt_enabled_users)
    sendgrid_category Settings::Email.new_user_summary["category"]

    # so we can distinguish these in the html.erb
    new_gt_enabled_users.map! {|u| u.faux = 9; u }

    # combine all users into one array
    @all_new_users = new_new_users.concat(converted_new_users).concat(new_gt_enabled_users)

    mail :from => "Shelby.tv <#{Settings::Email.notification_sender}>", 
      :to => "henry@shelby.tv", 
      :subject => Settings::Email.new_user_summary['subject'] % { :new_new_users => new_new_users.length, :converted_new_users => converted_new_users.length, :new_gt_enabled_users => new_gt_enabled_users.length  }
  end
  
end
