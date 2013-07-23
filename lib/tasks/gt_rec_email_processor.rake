namespace :recommendations do

  desc 'Send an email with one video to all real users'
  task :send_email => :environment do
    require "user_recommendation_processor"
    require "benchmark"

    time = Benchmark.measure do
      should_send_email = true
      should_send_pde_recs = false

      processor = GT::UserRecommendationProcessor.new(should_send_pde_recs, should_send_email)
      @stats = processor.process_and_send_rec_email()
    end

    proc_time = (time.real / 60).round(2)
    # send email summary to developers
    AdminMailer.weekly_email_summary(@stats, proc_time).deliver
  end
end
