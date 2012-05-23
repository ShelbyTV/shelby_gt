module GT
  class DeepLinkParser
	
    def self.find_deep_link(url)
      dlcached = GT::DeeplinkCache.where(:url => url).first
      if dlcached
          return dlcached[:videos]
      end
      urlinfos = deep_parse_url(url)
      if urlinfos
        #found deep videos, put in db
        dl = GT::DeeplinkCache.new
        dl.url = url
        dl.videos = urlinfos
        dl.time = Time.now
        begin
          dl.save
        rescue Mongo::OperationFailure => e
          # If this was a timing issue, and Deeplink got created after we checked, that means the Deeplink exists now.  See if we can't recover...
          dl = GT::DeeplinkCache.where(:url => url).first
          return dl.videos if dl
          Rails.logger.error "[GT::VideoManager#find_or_create_video_for_embedly_hash] rescuing Mongo::OperationFailure #{e}"
          return nil
        end
        return urlinfos
      end
    end 
    
    private

    BLACKLIST_REGEX = /freq\.ly|yfrog\.|4sq\.com|twitpic\.com|nyti\.ms|plixi\.com|instagr\.am|facebook\.com/i
    DOMAIN_REGEX = /\w*\.\w*\.\w*\/\w*/
    #repeated code fix...
    def self.url_is_blacklisted?(url)
      url.match(BLACKLIST_REGEX) != nil
    end

    def self.deep_parse_url(url)
      #require 'open-uri'
      #require 'strscan'
      
      # don't check instagram will update later
      return nil if self.url_is_blacklisted?(url)
      # check if it is deeper than domain
    
      return nil unless url.match(DOMAIN_REGEX)
      # check cache here?
      #

      begin
        deepread = open(url).read

      rescue
        # find exception to rescue from
        return nil
      end
      parsedoc = Nokogiri::HTML(deepread)
      embed_elements = []
      embed_elements += parsedoc.xpath("//iframe")
      embed_elements += parsedoc.xpath("//embed")
      urls = []
      for embed in embed_elements
          for k,v in embed
              if k == "src"
                  urls << v
              end
          end
      end
      return urls unless urls.empty?
      return nil
    end
	
	
  end
end
