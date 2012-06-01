require 'bean_job'
require 'video_manager'
require 'memcached_manager'
require 'twitter_normalizer'
require 'facebook_normalizer'
require 'tumblr_normalizer'
require 'social_sorter'

module GT
  module Arnold
    class JobProcessor
      #url_cache is a (list, int) tuple that represents a fixed size cache
      def self.process_job(jobs, fibers, max_fibers, url_cache=nil, use_em = true)
        prev_urls = []
        results = []
  	jobs.each do |job|

          job_start_t = Time.now
  	  unless job_details = GT::Arnold::BeanJob.parse_job(job)
  	    Rails.logger.error "[GT::Arnold::JobProcessor.process_job(job:#{job.jobid})] No job_details.  Indicates some issue during job parsing."
  	    clean_up(job, fibers, max_fibers, job_start_t)
  	    results << :bad_job
            next
	  end
	  # 1) Get videos at that URL
	  if job_details[:expanded_urls].is_a?(Array)
	    vids = []
	    job_details[:expanded_urls].each do |url|
	    # Experimentation has shown that we cannot rely on these URLs to actually be expanded
              unless prev_urls.include? url
                sleep_if_other_fiber_is_processing(url, url_cache, use_em)
                prev_urls << url
              end
	      vids += GT::VideoManager.get_or_create_videos_for_url(url, true, GT::Arnold::MemcachedManager.get_client, true, true, 1.0)
	    end
	  else
            url = job_details[:url]
            unless prev_urls.include? url
              sleep_if_other_fiber_is_processing(url, url_cache, use_em)
              prev_urls << url
            end
  	    vids = GT::VideoManager.get_or_create_videos_for_url(url, true, GT::Arnold::MemcachedManager.get_client, true, true, 1.0)
          end
        
          if vids.empty?          
		      #Rails.logger.debug "[GT::Arnold::JobProcessor.process_job(job:#{job.jobid})] No videos found for #{job_details}"
	    clean_up(job, fibers, max_fibers, job_start_t) 
	    results << :no_videos
            next
	  end
		    
		    # 2) Normalize the incoming social post
          msg = GT::TwitterNormalizer.normalize_tweet(job_details[:twitter_status_update]) if job_details[:twitter_status_update]
          msg = GT::FacebookNormalizer.normalize_post(job_details[:facebook_status_update]) if job_details[:facebook_status_update]
          msg = GT::TumblrNormalizer.normalize_post(job_details[:tumblr_status_update]) if job_details[:tumblr_status_update]
          if msg == nil or msg.nickname.blank?
            Rails.logger.fatal "[GT::Arnold::JobProcessor.process_job(job:#{job.jobid})] Invalid social message. job: #{job}, job_details: #{job_details}, message: #{msg}"
            clean_up(job, fibers, max_fibers, job_start_t)
            results << :no_social_message
            next
          end
        
          # 3) get the observing user
          unless observing_user = User.find_by_provider_name_and_id(job_details[:provider_type].to_s, job_details[:provider_user_id].to_s)
          # In production, this is certainly an error (how are we getting jobs for Users not in the DB?)
          # But while testing, we're not using the real User DB, so this is expected
          Rails.logger.error "[GT::Arnold::JobProcessor.process_job(job:#{job.jobid})] No observing_user for provider '#{job_details[:provider_type]}' with id '#{job_details[:provider_user_id]}'"
          clean_up(job, fibers, max_fibers, job_start_t) 
          results << :no_observing_user
          next
        end
        
        # 4) For each video, post it into the system
        res = []
        vids.each { |v| res << GT::SocialSorter.sort(msg, v, observing_user, is_deep) }
  		  
  	clean_up(job, fibers, max_fibers, job_start_t) 
  	results << res
      end
      return results
    end
    
      private

        def self.sleep_if_other_fiber_is_processing(url, url_cache, use_em)
          return nil unless url_cache
          if url_cache[0].include? url
            if use_em
              EM::Synchrony.sleep 1
            else
              sleep 1
            end
          else
            url_cache[0][url_cache[1]] = url
            url_cache[1] = (url_cache[1] + 1) % url_cache[0].length
          end
        end

      
        def self.clean_up(job, fibers, max_fibers, job_start_t)
		      # -- stats --
    	  StatsManager::StatsD.client.increment($statsd_jobs_processed_bucket)
    	  StatsManager::StatsD.client.timing($statsd_job_timing_bucket, Time.now - job_start_t)

    	  # -- cleanup --
    	  fibers.delete(Fiber.current)
    	  #Rails.logger.debug "[GT::Arnold::JobProcessor.process_job(job:#{job.jobid})] done with job, removed me from fibers, we're done here.  fibers: #{fibers.size} / #{max_fibers}"
	end
    end
  end
end
