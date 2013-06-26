namespace :rec_email_processor do

  desc 'Send an email with one video to all real users'
  task :send => :environment do
    require "user_email_processor"

    should_send_email = true
    email_processor = GT::UserEmailProcessor.new(should_send_email)
    email_processor.process_and_send_rec_email()

  end
end