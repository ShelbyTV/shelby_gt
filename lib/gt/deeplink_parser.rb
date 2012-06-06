require 'net/http'
require 'strscan'

module GT
  class DeeplinkParser
	
    DOMAIN_REGEX = /\w+\.\w+\/\w+/


    #returns a list of urls, empty list if none
    def self.find_deep_link(url)
  
      #don't check instagram
      return {:urls => [], :to_cache => false} if GT::UrlHelper.url_is_blacklisted?(url)

      # check if it is deeper than domain
      return {:urls => [], :to_cache => false} unless url.match(DOMAIN_REGEX)

      parsed_urls = deep_parse_url(url)
      #found deep videos, put in db
      return {:urls => parsed_urls[:urls], :to_cache => parsed_urls[:to_cache]}
    end 
    
    private

    # return deep linked urls, empty list if none
    def self.get_page_with_em(url, tries_left=5, sleep_time=2)
      http = EventMachine::HttpRequest.new(url, :connect_timeout => 5).get
      if http.response_header and http.response_header.status == 404
        # failure cache no videos
        return {:response => nil, :to_cache => true}
      end

      if http.error or http.response_header.status != 200
        return {:response => nil, :to_cache => true}
      end
      return {:response => http.response, :to_cache => true}
    end


    def self.get_page_with_net(url)
      response = Net::HTTP.get_response(url)
      return {:response => nil, :to_cache => false} unless response
    
      if response.code == "200"
        return {:response => response.body, :to_cache => true}
      elsif response.code == "404"
        return {:response => nil, :to_cache => true}
      else 
        return {:response => nil, :to_cache => false}
      end
    end

    
    
    def self.check_valid_url(url)
      matched = url.match(URI::regexp)
      return false unless matched
      if GT::UrlHelper.parse_url_for_provider_info(url)
        return true
      else
        return false
      end
    end
      
    def self.parse_with_nokogiri(page)
      parsedoc = Nokogiri::HTML(deep_response)
      embed_elements = []
      embed_elements += parsedoc.xpath("//iframe")
      embed_elements += parsedoc.xpath("//embed")
      urls = []
      for embed in embed_elements
        for k,v in embed
          if k == "src"
            urls << v if check_valid_url(v)
          end
        end
      end
      return {:urls => urls, to_cache => true}
    end

    def self.parse_with_regex(page)
      #first ignore invalid bytes
      page.encode!('UTF-16', 'UTF-8', :invalid => :replace, :replace => '')
      page.encode!('UTF-8', 'UTF-16')
      #page.encode!('UTF-8', 'UTF-8', :invalid => :replace)
      scanner = StringScanner.new(page)
      urls = []
      while html = scanner.scan_until(/<iframe|<embed/)
        iframeline = scanner.scan_until(/<\/iframe>|<\/embed>/)
        next unless iframeline
        next unless src_url = iframeline[/src=.* /]
        startindex = src_url.index(/http:\/\//)
        endindex = src_url.index(/ /) - 1
        next unless startindex
        to_add = src_url[startindex...endindex].gsub(/&amp;/, "&")
        urls << to_add if check_valid_url(to_add)
      end
      return {:urls => urls, :to_cache => true}
    end

    def self.deep_parse_url(url, use_em=true)
      if use_em
        deep_http_response = get_page_with_em(url)
      else
        deep_http_response = get_page_with_net(url)
      end
      if deep_response = deep_http_response[:response]
        return parse_with_regex(deep_response)
      end
      return {:urls => [], :to_cache => deep_http_response[:to_cache]}
    end
	
	
  end
end