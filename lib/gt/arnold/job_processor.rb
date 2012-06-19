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

        job_start_t = Time.now
        prev_urls = []
        results = []
  	jobs.each do |job|

  	  unless job_details = GT::Arnold::BeanJob.parse_job(job)
  	    Rails.logger.error "[GT::Arnold::JobProcessor.process_job(job:#{job.jobid})] No job_details.  Indicates some issue during job parsing."
  	    StatsManager::StatsD.client.increment($statsd_jobs_processed_bucket)
  	    results << :bad_job
            next
	  end

	  vids = []
	  # 1) Get videos at that URL
	  if job_details[:expanded_urls].is_a?(Array)
	    job_details[:expanded_urls].each do |url|
	    # Experimentation has shown that we cannot rely on these URLs to actually be expanded
              unless prev_urls.include? url
                sleep_if_other_fiber_is_processing(url, url_cache, use_em)
                prev_urls << url
              end
	      video_response = GT::VideoManager.get_or_create_videos_for_url(url, true, GT::Arnold::MemcachedManager.get_client, true, true, $check_deep_prob)
              video_response[:videos].each do |v|
                vids << {:video => v, :from_deep => video_response[:from_deep]}
              end
	    end
	  else
            url = job_details[:url]
            if prev_urls.include? url
    	      StatsManager::StatsD.client.increment($statsd_jobs_cached_bucket)
            else prev_urls.include? url
              sleep_if_other_fiber_is_processing(url, url_cache, use_em)
              prev_urls << url
            end
  	    video_response = GT::VideoManager.get_or_create_videos_for_url(url, true, GT::Arnold::MemcachedManager.get_client, true, true, $check_deep_prob)
            video_response[:videos].each do |v|
              vids << {:video => v, :from_deep => video_response[:from_deep]}
            end
          end
        
          if vids.empty?          
		      #Rails.logger.debug "[GT::Arnold::JobProcessor.process_job(job:#{job.jobid})] No videos found for #{job_details}"
	    StatsManager::StatsD.client.increment($statsd_jobs_processed_bucket) 
	    results << :no_videos
            next
	  end
		    
		    # 2) Normalize the incoming social post
          msg = GT::TwitterNormalizer.normalize_tweet(job_details[:twitter_status_update]) if job_details[:twitter_status_update]
          msg = GT::FacebookNormalizer.normalize_post(job_details[:facebook_status_update]) if job_details[:facebook_status_update]
          msg = GT::TumblrNormalizer.normalize_post(job_details[:tumblr_status_update]) if job_details[:tumblr_status_update]
          if msg == nil or msg.nickname.blank?
            Rails.logger.info "[GT::Arnold::JobProcessor.process_job(job:#{job.jobid})] Invalid social message. job: #{job}, job_details: #{job_details}, message: #{msg}"
            StatsManager::StatsD.client.increment($statsd_jobs_processed_bucket)
            results << :no_social_message
            next
          end
        
          # 3) get the observing user
          unless observing_user = User.find_by_provider_name_and_id(job_details[:provider_type].to_s, job_details[:provider_user_id].to_s)
          # In production, this is certainly an error (how are we getting jobs for Users not in the DB?)
          # But while testing, we're not using the real User DB, so this is expected
          Rails.logger.error "[GT::Arnold::JobProcessor.process_job(job:#{job.jobid})] No observing_user for provider '#{job_details[:provider_type]}' with id '#{job_details[:provider_user_id]}'"
          StatsManager::StatsD.client.increment($statsd_jobs_processed_bucket) 
          results << :no_observing_user
          next
        end
        
        # 4) For each video, post it into the system
        res = []
        vids.each { |v_hash| res << GT::SocialSorter.sort(msg, v_hash, observing_user) }
  		  
  	StatsManager::StatsD.client.increment($statsd_jobs_processed_bucket) 
  	results << res
      end
      clean_up(jobs, fibers, max_fibers, job_start_t)
      return results
  end
  
      private

        def self.sleep_if_other_fiber_is_processing(url, url_cache, use_em)
          return nil unless url_cache
          if url_cache[0].include? url
            if use_em
    	      StatsManager::StatsD.client.increment($statsd_jobs_cached_bucket)
              EM::Synchrony.sleep 1
            else
              sleep 1
            end
          else
            url_cache[0][url_cache[1]] = url
            url_cache[1] = (url_cache[1] + 1) % url_cache[0].length
          end
        end

      
        def self.clean_up(jobs, fibers, max_fibers, job_start_t)
		      # -- stats --
    	  StatsManager::StatsD.client.timing($statsd_job_timing_bucket, (Time.now - job_start_t)/jobs.length)

    	  # -- cleanup --
    	  fibers.delete(Fiber.current)
    	  #Rails.logger.debug "[GT::Arnold::JobProcessor.process_job(job:#{job.jobid})] done with job, removed me from fibers, we're done here.  fibers: #{fibers.size} / #{max_fibers}"
	end
    end
  end
end
