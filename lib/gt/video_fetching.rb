# encoding: UTF-8
require 'beanstalk-client'

# TODO: ***Need to test this class*** (if it is tested, move tests into new class)
module GT
  #TODO: rename "PredatorManager" 
  #TODO: add comments (for class) explaining this thing
  class VideoFetching
    
    # gets as many videos from statuses available and adds user to site streaming
    def self.initialize_video_processing(u, a)
      return unless Settings::Beanstalk.available

      begin
        #TODO FIXME this settins is not _ip it's _url
        bean = Beanstalk::Connection.new(Settings::Beanstalk.beanstalk_ip)
        case a.provider
        when 'twitter'
          tw_add_backfill(a, bean)
          tw_add_to_stream(a, bean)
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
        beanstalk = Beanstalk::Connection.new(Settings::Beanstalk.beanstalk_ip)
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
        bean.use(Settings::Beanstalk.tumblr_add_user)      # insures we are using watching tumblr_backfill tube
        add_user_job = {:tumblr_id => a.uid, :oauth_token => a.oauth_token, :oauth_secret => a.oauth_secret}
        bean.put(add_user_job.to_json)
      end
    
      def self.fb_add_user(a, bean)
        bean.use(Settings::Beanstalk.facebook_add_user)      # insures we are using watching fb_add_user tube
        add_user_job = {:fb_id => a.uid, :fb_access_token => a.oauth_token}
        bean.put(add_user_job.to_json)
      end

      def self.tw_add_backfill(a, bean)
        bean.use(Settings::Beanstalk.twitter_backfill)      # insures we are using watching tw_backfill tube
        backfill_job = {:action=>'add_user', :twitter_id => a.uid, :oauth_token => self.oauth_token, :oauth_secret => self.oauth_secret}
        bean.put(backfill_job.to_json)
      end

      def self.tw_add_to_stream(a, bean)
        bean.use(Settings::Beanstalk.twitter_add_stream)    # insures we are using tw_stream_add tube
        stream_job = {:action=>'add_user', :twitter_id => a.uid}
        bean.put(stream_job.to_json)
      end
      #
      #
      ###########################################
    

  end
end