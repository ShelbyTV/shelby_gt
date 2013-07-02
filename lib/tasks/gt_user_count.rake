namespace :stats do

  desc 'Send email with current email count'
  task :user_count_report => :environment do
    require "benchmark"
    require 'api_clients/google_analytics_client'

    time = Benchmark.measure do
      real_user_count = User.collection.find(
        {:$and => [
          {:ag => true}, # gt_enabled
          {:ac => {:$in => [0,2] }} # user_type
          ]}
        ).count

      @stats = {
        real_user_count: real_user_count
      }

      begin
        APIClients::GoogleAnalyticsClient.track_event('Stats', 'User Count', 'Real GT Users', real_user_count)
      rescue Exception => e
        Rails.logger.info "[USER COUNT REPORT] Error posting to GA: #{e}"
      end

    end

    proc_time = (time.real / 60).round(2)
    # send email summary to developers
    AdminMailer.user_stats_report(@stats, proc_time).deliver
  end
end
