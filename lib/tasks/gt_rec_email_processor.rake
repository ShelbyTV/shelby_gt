namespace :rec_email_processor do

  desc 'Send an email with one video to all real users'
  task :send => :environment do
    require "user_email_processor"
    require "benchmark"

    time = Benchmark.measure do
      should_send_email = true
      email_processor = GT::UserEmailProcessor.new(should_send_email)
      # temporarily restricting this to send only to us for testing
      @stats = email_processor.process_and_send_rec_email(['iceberg901', 'spinosa', 'henry', 'chris', 'edon', 'matyus', 'keren', 'frash', 'vondoom', 'reece'])
    end

    proc_time = (time.real / 60).round(2)
    # send email summary to developers
    AdminMailer.weekly_email_summary(@stats, proc_time).deliver
  end
end
