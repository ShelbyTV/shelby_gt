require 'net/http'
require 'memcached_link_resolving_cache'

require 'open-uri'
require 'nokogiri'

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
      return nil unless url
      
      yt = parse_url_for_youtube_provider_info(url)
      return yt if yt
      
      vim = parse_url_for_vimeo_provider_info(url)
      return vim if vim
      
      # ESPN
      es = parse_url_for_espn_provider_info(url)
      return es if es
      
      dm = parse_url_for_dailymotion_provider_info(url)
      return dm if dm
      
      # CollegeHumor
      ch = parse_url_for_collegehumor_provider_info(url)
      return ch if ch
      
      # Ooyala (TechCrunch, Bloomberg embeds)
      ooyala = parse_url_for_ooyala_embed(url)
      return ooyala if ooyala
      
      # Hulu
      hu = parse_url_for_hulu_provider_info(url)
      return hu if hu
      
      # TechCrunch
      tc = parse_url_for_techcrunch_provider_info(url)
      return tc if tc
    
      # Blip
      bp = parse_url_for_blip_provider_info(url)
      return bp if bp
      
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
    
    # a little transformation on some URLs allows our URL analyst services to better process them
    def self.post_process_url(url)
      # http://vimeo.com/channels/hdgirls#30492458 => http://vimeo.com/30492458
      vimeo_ch_check = VIMEO_URL_REGEX.match(url)
      url = "http://vimeo.com/" + vimeo_ch_check[2] if (vimeo_ch_check and vimeo_ch_check[2])
      return url
    end
    
    def self.url_is_shelby?(url)
      url.match(SHELBY_URL_REGEX) != nil
    end
    
    # also using it for deep link parsing  
    # we see lots of these, don't want to waste time resolving them
    BLACKLIST_REGEX = /freq\.ly|yfrog\.|4sq\.com|twitpic\.com|nyti\.ms|plixi\.com|instagr\.am|facebook\.com/i
    def self.url_is_blacklisted?(url)
      url.match(BLACKLIST_REGEX) != nil
    end
 
    private

      SHELBY_URL_REGEX = /shel\.tv|shelby\.tv/i
      VIMEO_URL_REGEX = /(http:\/\/vimeo.com\/\D*\#)(\d*)/       

      # we see URLs w/o scheme and it kills em-http-request / addressable
      # so, if the URL doesn't have a scheme, we default it to http
      VALID_URL_REGEX = /^(http:\/\/|https:\/\/)/i
      def self.ensure_url_has_scheme!(url)
        url.match(VALID_URL_REGEX) ? url : "http://#{url}"
      end
      
      ##############################################
      #------ URL Resolution --------
      ##############################################
      
      def self.resolve_url_with_eventmachine(url)
        begin
          http = EventMachine::HttpRequest.new(url, :connect_timeout => Settings::EventMachine.connect_timeout).head({:redirects => Settings::EventMachine.max_redirects})
          return http.last_effective_url.normalize.to_s
        rescue Addressable::URI::InvalidURIError => e
          Rails.logger.info("[GT::UrlHelper#resolve_url_with_eventmachine] url #{url} threw InvalidURIError: #{e}")
          return nil
        end
      end
      
      def self.resolve_url_with_net_http(url, limit)
        return url if limit == 0
       
        begin 
          response = Net::HTTP.get_response(URI.parse(url))
        ensure
          return url unless response.kind_of?(Net::HTTPRedirection)
        end

        # response.kind_of?(Net::HTTPRedirection) is true
        redirect_url = response['location'].nil? ? response.body.match(/<a href=\"([^>]+)\">/i)[1] : response['location']
        return self.resolve_url_with_net_http(redirect_url, limit-1)
      end
      
      ##############################################
      #------ Caching --------
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
      # This could probably be moved into its own file, but I can't think of a good name for it right now...
      ##############################################
      
      # YouTube
      def self.parse_url_for_youtube_provider_info(url)
        #normal, long youtube links
        match_data = url.match( /youtube.*\/([ev]|embed)+\/([\w-]*)|v=([\w-]*)([&%]+.*\z|\z)/i )
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
      
      # Vimeo
      def self.parse_url_for_vimeo_provider_info(url)
        match_data = url.match( /vimeo.+(\/|hd#|videos\/|clip_id=)(\d+)(\z|\D)/i )
        if match_data and match_data.size == 4
          return {:provider_name => "vimeo", :provider_id => match_data[2]}
        end
      end
      
      # DailyMotion
      def self.parse_url_for_dailymotion_provider_info(url)
        match_data = url.match( /dailymotion.+(video\/)([\w-]{5,9})[_?\\"']+/i )
        if match_data and match_data.size == 3
          return {:provider_name => "dailymotion", :provider_id => match_data[2]}
        end
      end
      
      # CollegeHumor
      def self.parse_url_for_collegehumor_provider_info(url)
        match_data = url.match( /collegehumor.+(clip_id=|video\/|e\/)([\d]*)/i )
        if match_data and match_data.size == 3
          return {:provider_name => "collegehumor", :provider_id => match_data[2]}
        end
      end
      
      # Hulu
      def self.parse_url_for_hulu_provider_info(url)
        match_data = url.match( /hulu.+\/(\d{6,})/i )
        if match_data and match_data.size == 2
          return {:provider_name => "hulu", :provider_id => match_data[1]}
        end
      end
      
      # TechCrunch
      def self.parse_url_for_techcrunch_provider_info(url)
        #regular URLs
        match_data = url.match( /techcrunch.+id=([\w-]*)(&+.*\z|\z)/i )
        if match_data and match_data.size == 3
          return {:provider_name => "techcrunch", :provider_id => match_data[1]}
        end
        
        # N.B. TechCrunch embeds are detected by ooyala
      end
        
      # Detechs TechCrunch and Bloomberg
      def self.parse_url_for_ooyala_embed(url)
        # ooyala player embed
        match_data = url.match( /player.ooyala.com.+embedCode=([\w-]*)(&+.*\z|\z)/i )
        if match_data and match_data.size == 3
          return {:provider_name => "ooyala", :provider_id => match_data[1]}
        end
      end
    
      # Blip
      def self.parse_url_for_blip_provider_info(url)
        match_data = url.match( /blip.tv.+(play\/)([\w-]*)/i )
        if match_data and match_data.size == 3
          return {:provider_name => "bliptv", :provider_id => match_data[2]}
        end
      end
      
      # ESPN
      def self.parse_url_for_espn_provider_info(url)
        match_data = url.match( /espn.go.com\/video\/clip.+id=([\w-]*)(&+.*\z|\z)/i )
        if match_data and match_data.size == 3
          return {:provider_name => "espn", :provider_id => match_data[1]}
        end
      end
    
  end
end
