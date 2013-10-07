namespace :user_emails do

  desc 'Send an email with video recommednations to all real users'
  task :send_weekly_recommendation_email => :environment do
    require "benchmark"
    require "recommendation_email_processor"

    time = Benchmark.measure do
      @stats = GT::RecommendationEmailProcessor.process_send_weekly_rec_email_for_users({
        :send_emails => false,
        :user_nicknames => ['iceberg901']
      })
    end

    proc_time = (time.real / 60).round(2)
    # send email summary to developers
    AdminMailer.weekly_email_summary(@stats, proc_time).deliver
  end
end
