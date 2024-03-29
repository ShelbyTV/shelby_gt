#
# Handles the pulling and parsing of jobs from Beanstalk
#
module GT
  module Arnold
    class BeanJob
    
      # To keep resources down, and allow us to work on thousands of jobs simultaneously, we use one
      # connection to beanstalk.  But since a job has to be reserved then deleted before a connection can do
      # anything else, we immediately delete the job after reserving it, then process the job.
      # It's okay if we drop a job every so often, as may happen in this design.
      # We could get more robust by re-enqueing jobs with some TTL if there's an error, but that's over-engineering at this point.
      def self.get_and_delete_job
        begin
          #now using em-jack so a reserve w/o job won't block the reactor
          job = self.bean.reserve
          self.bean.delete(job) if job
          return job
        
        # don't think we need any of these rescue blocks w/ EMJack...  
        rescue Beanstalk::TimedOut 
          Rails.logger.debug "[Arnold::BeanJob#get_job] Beanstalk::TimeOut; this is normal when reserve doesn't get a job; returning nil."
          return nil
        
        rescue Errno::ETIMEDOUT => e
          Rails.logger.error "[Arnold::BeanJob#get_job] ERRNO ETIMEDOUT -- #{e} -- resetting beanstalk and retuning nil job"
          reset_bean
          return nil
        
        rescue Beanstalk::NotConnected => e
          Rails.logger.error "[Arnold::BeanJob#get_job] beanstalk NOT CONNECTED -- #{e} -- resetting beanstalk and retuning nil job"
          reset_bean
          return nil
        
        rescue => e
          Rails.logger.error "[Arnold::BeanJob#get_job] UNEXPECTED error -- #{e.inspect} -- #{e.class} -- returning nil job (not resetting beanstalk) -- BACKTRACE: #{e.backtrace.join('\n')}"
          return nil
        end
      
        #this should be unreachable, but let's be safe
        return nil
      end
    
      def self.parse_job(job)
        job_details = {}
      
        begin
          #Jobs are simple JSON
          # For some reason, we thought beanstalk wasn't always happy with all characters, so we URI encoded them first
          #job_json = JSON.parse(URI.unescape(job.body))
          #
          # But the unescaping is particularly non-performant, so we're now trying things w/o the URI escaping
          job_json = JSON.parse(job.body)
        rescue JSON::ParserError => e
          # some jobs are still URI escaped...
          begin
            job_json = JSON.parse(URI.unescape(job.body))
          rescue => e
            Rails.logger.error("[Arnold::BeanJob#parse_job(job:#{job.jobid})] BAD JOB: tried to URI.unescape but still could not process: #{job}")
            return false
          end
        rescue => e
          Rails.logger.error("[Arnold::BeanJob#parse_job(job:#{job.jobid})] BAD JOB: could not process: #{job}")
          return false
        end
      
        # parse out the things we expect from a job        
        job_details[:provider_type] =  job_json['provider_type']
        job_details[:provider_user_id] =  job_json['provider_user_id']
        
        job_details[:twitter_status_update] = job_json['twitter_status_update'] if job_json['twitter_status_update']
        job_details[:facebook_status_update] = job_json['facebook_status_update'] if job_json['facebook_status_update']
        job_details[:tumblr_status_update] = job_json['tumblr_status_update'] if job_json['tumblr_status_update']    
        job_details[:has_status] = true if job_details[:twitter_status_update] or job_details[:facebook_status_update] or job_details[:tumblr_status_update]
        
        # The traditional, expected url as parsed by Predator
        job_details[:url] =  job_json['url']
        # Twitter provided expanded URLs (that we don't need to resolve)
        # ***FALSE*** Some research has shown that we cannot trust twitter to return these expanded (updated JobProcessor based on this)
        if job_details[:twitter_status_update] and job_details[:twitter_status_update]["entities"] and job_details[:twitter_status_update]["entities"]["urls"]
          expanded_urls = (job_details[:twitter_status_update]["entities"]["urls"].map { |u| u["expanded_url"] }).compact
          job_details[:expanded_urls] = expanded_urls unless expanded_urls.blank?
        end
      
        # Make sure the job looks good
        unless (job_details[:url] or job_details[:expanded_urls]) and job_details[:provider_type] and job_details[:provider_user_id] and job_details[:has_status]
          Rails.logger.error("[Arnold::BeanJob#parse_job(job:#{job.jobid})] BAD JOB: could not process: #{job}")
          return false
        end
      
        if job_details[:tumblr_status_update].class == Fixnum
          Rails.logger.error("[Arnold::BeanJob#parse_job(job:#{job.jobid})] BAD JOB: tumblr status is a Fixnum, should be a hash. // job: #{job} // job.body: #{job.body} // job_json: #{job_json}")
          return false
        end
      
        #Rails.logger.debug("[Arnold::BeanJob#parse_job(job:#{job.jobid})] Parsed Job: #{job_details}")
        return job_details
      end
    
    
      private
    
        @@beanstalk = nil

        def self.bean
          unless @@beanstalk
            # create the EventMachine connection
            @@beanstalk = EMJack::Connection.new(:host => Settings::Beanstalk.host, :port => Settings::Beanstalk.port)
          
            # Make it fiber aware (all commands now run synchronously via fiber yield/resume)
            @@beanstalk.fiber!
          
            # Watch our tubes
            @@beanstalk.watch(Settings::Beanstalk.tubes["link_processing_high"])
            @@beanstalk.watch(Settings::Beanstalk.tubes["link_processing"])
          
            # N.B. We are currently not devoting any high-priority-only processes.
            # Beanstalk will prioritize by job creation time, not by tube
          end

          @@beanstalk
        end
      
        def self.reset_bean
          @@beanstalk = nil
        end
    
    end
  end
end