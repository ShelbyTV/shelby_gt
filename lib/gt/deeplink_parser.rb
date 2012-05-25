require 'net/http'

module GT
  class DeeplinkParser
	
    DOMAIN_REGEX = /\w*\.\w*\/\w*/

    #returns a list of urls, empty list if none
    def self.find_deep_link(url)
  
      #don't check instagram
      return [[], false] if GT::UrlHelper.url_is_blacklisted?(url)

      # check if it is deeper than domain
      return [[], false] unless url.match(DOMAIN_REGEX)

      urlinfos, tocache = deep_parse_url(url)
      #found deep videos, put in db
      return [urlinfos, tocache]
    end 
    
    private

    # return deep linked urls, empty list if none
    def self.get_page_em(url, tries_left=5, sleep_time=2)
      http = EventMachine::HttpRequest.new(url, :connect_timeout => 5).get
      if http.response_header and http.response_header.status == 404
        # failure cache no videos
        return [nil, true]
      end

      #don't cache
      if http.error or http.response_header.status != 200
        if tries_left <= 0
          return [nil, false]
        else
          EventMachine::Synchrony.sleep(sleep_time)
          return get_page(url, tries_left-1, sleep_time*2)
        end
      end
      return [http.response, true]
    end

    def self.get_page_net(url)
      response = Net::HTTP.get_response(url)
      return [nil, false] unless response
    
      if response.code == "200"
        return [response.body, true]
      elseif response.code == "404"
        return [nil, true]
      else 
        return [nil, false]
      end
    end

    def self.deep_parse_url(url)
      deep_response, to_cache = get_page_em(url)
      if deep_response
        parsedoc = Nokogiri::HTML(deep_response)
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
        return [urls, true]
      end
      return [[], to_cache]
    end
	
	
  end
end
