namespace :rec_email_processor do

  desc 'Send an email with one video to all real users'
  task :send_email => :environment do
    require "user_email_processor"


  end
end
