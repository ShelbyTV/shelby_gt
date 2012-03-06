require 'net/http'
require 'memcached_link_resolving_cache'
require 'memcached_video_processing_link_cache'

# A helper module for URLs
# works with or without EventMachine and Memcache
#
module GT
  class UrlHelper
    
    # returns nil if we shouldn't processes this url
    def self.get_clean_url(url)
      url = self.ensure_url_has_scheme!(url)
      return nil if self.url_is_blacklisted?(url)
      return url
    end
    
    # Try to pull the provider's name and id so we can check out DB
    # return nil if we can't
    def self.parse_url_for_provider_info(url)
      yt = self.parse_url_for_youtube_provider_info(url)
      return yt if yt
      
      #TODO: import everything else from broadcast.rb
      
      return nil
    end
    
    # resolve the URL, using a cache if available
    def self.resolve_url(url, use_em=false, memcache_client=nil)
      # 1) Check cache
      if memcache_client and (cache = check_link_resolving_cache(url, memcache_client))
        return cache.resolved_url
      end
      
      # 2) resolve (event machine or otherwise)
      resolved_url = use_em ? self.resolve_url_with_eventmachine(url) : self.resolve_url_with_net_http(url, 5)
    
      # 3) cache this
      cache_link_resolution(url, resolved_url, memcache_client) if memcache_client
    
      return resolved_url
    end
    
    SHELBY_URL_REGEX = /shel\.tv|shelby\.tv/i
    def self.url_is_shelby?(url)
      url.match(SHELBY_URL_REGEX) != nil
    end
    
    private       
   
      # we see lots of these, don't want to waste time resolving them
      BLACKLIST_REGEX = /freq\.ly|yfrog\.|4sq\.com|twitpic\.com|nyti\.ms|plixi\.com|instagr\.am/i
      def self.url_is_blacklisted?(url)
        url.match(BLACKLIST_REGEX) != nil
      end
   
      # we see URLs w/o scheme and it kills em-http-request / addressable
      # so, if the URL doesn't have a scheme, we default it to http
      VALID_URL_REGEX = /^(http:\/\/|https:\/\/)/i
      def self.ensure_url_has_scheme!(url)
        url.match(VALID_URL_REGEX) ? url : "http://#{url}"
      end
      
      ##############################################
      #------ URL Resolution --------
      ##############################################
      
      #TODO test the event machine stuff
      def self.resolve_url_with_eventmachine(url)
        begin
          http = EventMachine::HttpRequest.new(url, :connect_timeout => connect_timeout).head( {:redirects => max_redirects} )
          return http.last_effective_url.normalize.to_s
        rescue Addressable::URI::InvalidURIError => e
          Rails.logger.info("[GT::UrlHelper#resolve_url_with_eventmachine] url #{url} threw InvalidURIError: #{e}")
          return nil
        end
      end
      
      def self.resolve_url_with_net_http(url, limit)
        return url if limit == 0
        
        response = Net::HTTP.get_response(URI.parse(url))
        if response.kind_of?(Net::HTTPRedirection)
          redirect_url = response['location'].nil? ? response.body.match(/<a href=\"([^>]+)\">/i)[1] : response['location']
          return self.resolve_url_with_net_http(redirect_url, limit-1)
        else
          return url
        end
      end
      
      ##############################################
      #------ Cacheing --------
      ##############################################
      
      def self.check_link_resolving_cache(url, memcache_client)
        begin
          #memcache_client is asynchronous via EventMachine
          return MemcachedLinkResolvingCache.find_by_original_url(url, memcache_client)
        rescue Errno::EAGAIN => e
          return false
        rescue Timeout::Error => e
          return false
        rescue => e
          Rails.logger.error("[GT::UrlHelper#check_link_resolving_cache] MemcachedLinkResolvingCache#find_by_original_url threw ? #{e} -- BACKTRACE: #{e.backtrace.join('\n')}")
          return false
        end
      end

      def self.cache_link_resolution(url, resolved_url, memcache_client)
        begin
          #memcache_client is asynchronous via EventMachine
          MemcachedLinkResolvingCache.create({:original_url => url, :resolved_url => resolved_url}, memcache_client) if resolved_url
        rescue Errno::EAGAIN => e
        rescue Timeout::Error => e
        rescue => e
          Rails.logger.error("[GT::UrlHelper#cache_link_resolution] MemcachedLinkResolvingCache#create threw ? #{e} -- BACKTRACE: #{e.backtrace.join('\n')}")
        end
      end
      
      ##############################################
      #------ parsing URLs for unique video --------
      ##############################################
      
      # YouTube
      def self.parse_url_for_youtube_provider_info(url)
        #normal, long youtube links
        match_data = url.match( /youtube.*\/([ev]|embed)+\/([\w-]*)|v=([\w-]*)(&+.*\z|\z)/i )
        if match_data and match_data.size >= 2
          id = match_data[2] unless match_data[2].blank?
          id = match_data[3] unless match_data[3].blank?
          return {:provider_name => "youtube", :provider_id => id}
        end
        
        #youtu.be short links
        match_data = url.match( /youtu\.be\/([\w-]*)(\?+.*\z|\z)/i )
        if match_data and match_data.size >= 1
          return {:provider_name => "youtube", :provider_id => match_data[1]}
        end
      end
    
    
  end
end