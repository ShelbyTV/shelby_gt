require 'bean_job'
require 'video_manager'
require 'memcached_manager'
require 'twitter_normalizer'
#TODO require 'facebook_normalizer'
#TODO require 'tumblr_normalizer'
require 'social_sorter'

module GT
  module Arnold
    class JobProcessor
    
      def self.process_job(job, fibers, max_fibers)
        job_start_t = Time.now
  		  
  		  unless job_details = GT::Arnold::BeanJob.parse_job(job)
  		    Rails.logger.error "[GT::Arnold::JobProcessor.process_job(job:#{job.jobid})] No job_details.  Indicates some issue during job parsing."
  		    return :bad_job
		    end
		    
		    # 1) Get videos at that URL
		    url = job_details[:url]
		    if (vids = GT::VideoManager.get_or_create_videos_for_url(url, true, GT::Arnold::MemcachedManager.get_client)).empty?
		      Rails.logger.debug "[GT::Arnold::JobProcessor.process_job(job:#{job.jobid})] No videos found at #{url}"
		      return :no_videos
	      end
		    
		    # 2) Normalize the incoming social post
        msg = GT::TwitterNormalizer.normalize_tweet(job_details[:twitter_status_update]) if job_details[:twitter_status_update]
        #TODO msg = GT::FacebookNormalizer.normalize_post(job_details[:facebook_status_update]) if job_details[:facebook_status_update]
        #TODO msg = GT::TumblrNormalizer.normalize_blog(job_details[:tumblr_status_update]) if job_details[:tumblr_status_update]
        unless msg
          Rails.logger.error "[GT::Arnold::JobProcessor.process_job(job:#{job.jobid})] No social message. job: #{job}, job_details: #{job_details}"
          return :no_social_message
        end
        
        # 3) get the observing user
        observing_user = User.find_by_provider_name_and_id(job_details[:provider_type].to_s, job_details[:provider_user_id].to_s)
        
        # 4) For each video, post it into the system
        res = []
        vids.each { |v| res << GT::SocialSorter.sort(msg, v, observing_user) }
        
        # TODO -- stats
  		  #Stats.timing($statsd_job_timing_bucket, Time.now - job_start_t)
  		  #Stats.increment($statsd_jobs_processed_bucket)
    
  		  # -- cleanup --
  		  fibers.delete(Fiber.current)
  		  Rails.logger.debug "[GT::Arnold::JobProcessor.process_job(job:#{job.jobid})] done with job, removed me from fibers, we're done here.  fibers: #{fibers.size} / #{max_fibers}"
  		  
  		  return res
      end
    
    end
  end
end