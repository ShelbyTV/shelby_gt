namespace :rec_email_processor do

  desc 'Send an email with one video to all real users'
  task :send => :environment do
    require "user_email_processor"
    require "benchmark"

    time = Benchmark.measure do
      should_send_email = true
      email_processor = GT::UserEmailProcessor.new(should_send_email)
      @stats = email_processor.process_and_send_rec_email()
    end

    # send email summary to developers
    AdminMailer.weekly_email_summary(@stats, time.real).deliver
  end
end
