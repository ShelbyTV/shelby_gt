namespace :user_emails do

  desc 'Send an email with video recommednations to all real users'
  task :send_weekly_recommendation_email, [:send_emails, :user_nicknames] => :environment do |t, args|
    require "benchmark"
    require "recommendation_email_processor"

    args.with_defaults(:send_emails => "false", :user_nicknames => nil)

    email_options = {
      :send_emails => "true".casecmp(args[:send_emails]) == 0
    }
    email_options[:user_nicknames] = args[:user_nicknames].split(",") if args[:user_nicknames]

    time = Benchmark.measure do
      @stats = GT::RecommendationEmailProcessor.process_send_weekly_rec_email_for_users(email_options)
    end

    proc_time = (time.real / 60).round(2)
    # send email summary to developers
    AdminMailer.weekly_email_summary(@stats, proc_time).deliver
  end
end
