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
          #return {:shelby_hash => JSON.parse(cache.shelby_json)} if cache.shelby_json
        rescue JSON::ParserError => e
          Rails.logger.error("[GT::UrlVideoDetector#examine_url_for_video] JSON::ParserError on embedly_json=#{cache.embedly_json} / returning nil") if cache.embedly_json
          #Rails.logger.error("[GT::UrlVideoDetector#examine_url_for_video] JSON::ParserError on shelby_json=#{cache.shelby_json} / returning nil") if cache.shelby_json
          return nil
        end
        return nil
      end
      
      # Cache miss!  See if one of our services can find video there...
      
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
        return nil unless url_matches_embedly_video_regex(url)
        
        embedly_url = "http://api.embed.ly/1/oembed?url=#{CGI.escape(url)}&format=json&key=#{Settings::Embedly.key}"

        return use_em ? check_embedly_for_video_with_em(url, embedly_url, memcache_client) : check_embedly_for_video_with_net_http(url, embedly_url, memcache_client)
      end
      
      def self.check_embedly_for_video_with_em(orig_url, embedly_url, memcache_client)
        http = EventMachine::HttpRequest.new(embedly_url, :connect_timeout => 5).get({:head=>{'User-Agent'=>Settings::Embedly.user_agent}})
        
        if http.response_header and http.response_header.status == 404
          # cache legit failure
          add_link_to_video_processing_cache(orig_url, nil, memcache_client)
          return nil
        end

        if http.error or http.response_header.status != 200
          # some error, not caching
          Rails.logger.error( "[GT::UrlVideoDetector#check_embedly_for_video_with_em] http error requesting #{embedly_url} / http.error: #{http.error} / http.response_header: #{http.response_header} / http.response: #{http.response}")
          return nil
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
      
      # Check if the given url matches the embeddable video urls from embed.ly
      # Must match http://api.embed.ly/docs/service
      def self.url_matches_embedly_video_regex(url)
        Embedly::Regexes::VIDEO_REGEXES.each do |regex|
          return true if url =~ regex
        end
        return false
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