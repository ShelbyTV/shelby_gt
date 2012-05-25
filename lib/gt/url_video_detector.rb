require 'net/http'
require 'memcached_video_processing_link_cache'
require 'embedly_regexes'

module GT
  class UrlVideoDetector
    
    # return nil if no video was found
    # otherwise returns an array of video hashes
    def self.examine_url_for_video(url, use_em=false, memcache_client=nil)
      # 1) check the cache
      if cache = check_video_processing_link_cache(url, memcache_client)
        begin
          return [{:embedly_hash => JSON.parse(cache.embedly_json)}] if cache.embedly_json
          #return [{:shelby_hash => cache.shelby_hash}] if cache.shelby_hash
        rescue JSON::ParserError => e
          Rails.logger.error("[GT::UrlVideoDetector#examine_url_for_video] JSON::ParserError on embedly_json=#{cache.embedly_json} / returning nil")
          return nil
        end
        return nil
      end
      
      # Cache miss!  
      # We should pretty much *always* have a cache miss here: The first time we see Video at a URL, it's added to DB.  The next time we see that URL,
      # we should pull Video from DB, and not have to resort to the methods of this class.
      
      # See if one of our services can find video there...
      
      #TODO in the future 2) check our own service
      #shelby_json = check_shelby_for_video(url, use_em)
      #if shelby_json
      #  begin
      #    shelby_json_parsed = JSON.parse(shelby_json)
      #    NEED SOME WAY TO STORE OUR SHIT A LITTLE DIFFERENT, I THINK
      #    add_link_to_video_processing_cache(url, shelby_json, memcache_client, :shelby)
      #    return {:shelby_hash => shelby_json_parsed}
      #  rescue JSON::ParserError => e
      #    Rails.logger.error("[GT::UrlVideoDetector#examine_url_for_video] JSON::ParserError on shelby_json=#{shelby_json} / returning nil")
      #    return nil
      #  end
      #end
      
      # 3) check embed.ly
      embedly_json = check_embedly_for_video(url, use_em, memcache_client)
      if embedly_json
        begin
          embedly_json_parsed = JSON.parse(embedly_json)
          # for backwards compatibility, we cache the raw json
          add_link_to_video_processing_cache(url, embedly_json, memcache_client)
          return [{:embedly_hash => embedly_json_parsed}]
        rescue JSON::ParserError => e
          Rails.logger.error("[GT::UrlVideoDetector#examine_url_for_video] JSON::ParserError on embedly_json=#{embedly_json} / returning nil")
          return nil
        end
      end
      
      # 4) We've found nothing (that was already cached if it wasn't due to an error)
      return nil
    end
    
    private
    
      ##############################################
      #------ Embed.ly --------
      ##############################################
      
      # returns the raw JSON from http.response
      def self.check_embedly_for_video(url, use_em, memcache_client)
        return nil unless Embedly::Regexes.video_regexes_matches?(url)
        
        embedly_url = "http://api.embed.ly/1/oembed?url=#{CGI.escape(url)}&format=json&key=#{Settings::Embedly.key}"

        return use_em ? check_embedly_for_video_with_em(url, embedly_url, memcache_client) : check_embedly_for_video_with_net_http(url, embedly_url, memcache_client)
      end
      
      def self.check_embedly_for_video_with_em(orig_url, embedly_url, memcache_client, tries_left=5, sleep_time=2)
        http = EventMachine::HttpRequest.new(embedly_url, :connect_timeout => 5).get({:head=>{'User-Agent'=>Settings::Embedly.user_agent}})
        
        if http.response_header and http.response_header.status == 404
          # cache legit failure
          add_link_to_video_processing_cache(orig_url, nil, memcache_client)
          return nil
        end

        if http.error or http.response_header.status != 200
          if tries_left <= 0
            # some error, not caching
            Rails.logger.error( "[GT::UrlVideoDetector#check_embedly_for_video_with_em] http error requesting #{embedly_url} / http.error: #{http.error} / http.response_header: #{http.response_header} / http.response: #{http.response} // DONE RETRYING: tries_left: #{tries_left}, sleep_time: #{sleep_time}")
            return nil
          else
            #pause and retry
            Rails.logger.debug( "[GT::UrlVideoDetector#check_embedly_for_video_with_em] http error requesting #{embedly_url} / http.error: #{http.error} / http.response_header: #{http.response_header} / http.response: #{http.response} // RETYRING: tries_left: #{tries_left}, sleep_time: #{sleep_time}")
            EventMachine::Synchrony.sleep(sleep_time)
            return check_embedly_for_video_with_em(orig_url, embedly_url, memcache_client, tries_left-1, sleep_time*2)
          end
        end
        
        #valid response is cached above
        return http.response
      end
    
      def self.check_embedly_for_video_with_net_http(orig_url, embedly_url, memcache_client)
        response = Net::HTTP.get_response(URI.parse(embedly_url))
        
        return nil unless response
        
        if response.code == "200"
          #valid response is cached above
          return response.body
        elsif response.code == "404"
          # cache legit failure
          add_link_to_video_processing_cache(orig_url, nil, memcache_client)
          return nil
        else
          return nil
        end
      end
    
      ##############################################
      #------ Caching --------
      ##############################################
      
      def self.check_video_processing_link_cache(url, memcache_client)
        return false unless memcache_client
        
        begin
          #memcache_client is asynchronous via EventMachine
          return MemcachedVideoProcessingLinkCache.find_by_url(url, memcache_client)
        rescue Errno::EAGAIN => e
          return false
        rescue Timeout::Error => e
          return false
        rescue => e
          Rails.logger.error("[GT::UrlVideoDetector#check_video_processing_link_cache)] MemcachedVideoProcessingLinkCache#find_by_url threw ? #{e} -- BACKTRACE: #{e.backtrace.join('\n')}")
          return false
        end
      end

      def self.add_link_to_video_processing_cache(url, json, memcache_client)
        return false unless memcache_client
        
        begin
          #memcache_client is asynchronous via EventMachine
          MemcachedVideoProcessingLinkCache.create({:url => url, :embedly_json => json}, memcache_client)
          return true
        rescue Errno::EAGAIN => e
        rescue Timeout::Error => e
        rescue => e
          Rails.logger.error("[GT::UrlVideoDetector#add_link_to_video_processing_cache] MemcachedVideoProcessingLinkCache#create threw ? #{e} -- BACKTRACE: #{e.backtrace.join('\n')}")
        end
      end
    
  end
end
