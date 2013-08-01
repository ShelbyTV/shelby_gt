# encoding: UTF-8
require 'beanstalk-client'

module GT

  #This manager puts jobs on our Queue that are accepted by the Predator
  #  to find links in social postings
  #
  class PredatorManager

    # gets as many videos from statuses available and adds user to site streaming
    def self.initialize_video_processing(u, a)
      return unless Settings::Beanstalk.available

      begin
        bean = Beanstalk::Connection.new(Settings::Beanstalk.url)
        case a.provider
        when 'twitter'
          Rails.logger.error "[PredatorManager] adding job to backfill #{u.id}" if u
          tw_add_backfill(a, bean)
          Rails.logger.error "[PredatorManager] added job to backfill #{u.id}" if u
          Rails.logger.error "[PredatorManager] adding job to stream #{u.id}" if u
          tw_add_to_stream(a, bean)
          Rails.logger.error "[PredatorManager] added job to stream #{u.id}" if u
        when 'facebook'
          fb_add_user(a, bean)
        when 'tumblr'
          tumblr_add_user(a, bean)
        end
      rescue => e
        Rails.logger.error("Error: Video processing initialization failed for user #{u.id}: #{e}")
      end
    end

    # Puts jobs on Queues to get most recent video we may have missed
    def self.update_video_processing(u, a)
      return unless Settings::Beanstalk.available

      begin
        beanstalk = Beanstalk::Connection.new(Settings::Beanstalk.url)
        case a.provider
        when 'twitter'
          #unneccssary as twitter doesn't need tokens for site streaming
        when 'facebook'
          #add_user job also updates user
          fb_add_user(a, beanstalk)
        when 'tumblr'
          #do we need this?
        end
      rescue => e
        Rails.logger.error("Error: Video processing update failed for user #{u.id}: #{e}")
      end
    end

    private

      ###########################################
      # Add jobs to Message Queue so Predator knows about new user
      #
      def self.tumblr_add_user(a, bean)
        bean.use(Settings::Beanstalk.tubes["tumblr_add_user"])      # insures we are using watching tumblr_backfill tube
        add_user_job = {:tumblr_id => a.uid, :oauth_token => a.oauth_token, :oauth_secret => a.oauth_secret}
        bean.put(add_user_job.to_json)
      end

      def self.fb_add_user(a, bean)
        bean.use(Settings::Beanstalk.tubes['facebook_add_user'])      # insures we are using watching fb_add_user tube
        add_user_job = {:fb_id => a.uid, :fb_access_token => a.oauth_token}
        bean.put(add_user_job.to_json)
      end

      def self.tw_add_backfill(a, bean)
        Rails.logger.error "[PredatorManager] starting to add job to backfill #{a.uid}" if a
        bean.use(Settings::Beanstalk.tubes['twitter_backfill'])      # insures we are using watching tw_backfill tube
        backfill_job = {:action=>'add_user', :twitter_id => a.uid, :oauth_token => a.oauth_token, :oauth_secret => a.oauth_secret}
        Rails.logger.error "[PredatorManager] creating job to backfill #{a.uid} : #{backfill_job}" if a
        bean.put(backfill_job.to_json)
        Rails.logger.error "[PredatorManager] PUT job on backfill #{a.uid}" if a
      end

      def self.tw_add_to_stream(a, bean)
        Rails.logger.error "[PredatorManager] starting to add job to stream #{a.uid}" if a
        bean.use(Settings::Beanstalk.tubes['twitter_add_stream'])    # insures we are using tw_stream_add tube
        Rails.logger.error "[PredatorManager] creating job to add job to stream #{a.uid}" if a
        stream_job = {:action=>'add_user', :twitter_id => a.uid}
        Rails.logger.error "[PredatorManager] creating job to stream #{a.uid} : #{stream_job}" if a
        bean.put(stream_job.to_json)
        Rails.logger.error "[PredatorManager] PUT job on stream #{a.uid}" if a
      end
      #
      #
      ###########################################


  end
end
