class AdminMailer < ActionMailer::Base
  include SendGrid
  
  helper :mail

  def new_user_summary(new_new_users, converted_new_users)
    sendgrid_category Settings::Email.admin_notification["admin"]

    @all_new_users = new_new_users.concat(converted_new_users)

    mail :from => "Shelby.tv <#{Settings::Email.notification_sender}>", 
      :to => "henry@shelby.tv", 
      :subject => Settings::Email.new_user_summary['subject'] % { :new_new_users => new_new_users.length, :converted_new_users => converted_new_users.length }
  end
  
end
