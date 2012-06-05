require 'net/http'
require 'strscan'

module GT
  class DeeplinkParser
	
    DOMAIN_REGEX = /\w+\.\w+\/\w+/

    youtubepattern = /http:\/\/(www\.)?youtube\.com\/embed\/[a-zA-Z0-9\-\_]*/
    vimeouni = /http:\/\/player\.vimeo\.com\/video\/[0-9]+(\?(([a-z]+=[0-9]+&?)+))?(\"| )/

    regexes = [youtubepattern,vimeouni]

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

      #don't cache
      if http.error or http.response_header.status != 200
        if tries_left <= 0
          Rails.logger.error("[GT::DeeplinkParser#get_page_with_em] http error requesting #{url} /http.error: #{http.error} / http.response_header: #{http.response_header} / http.response: #{http.response} // DONE RETRYING: tires_left: #{tries_left}, sleep_time: #{sleep_time}")
          return {:response => nil, :to_cache => false}
        else
          Rails.logger.debug( "[GT::DeeplinkParser#get_page_with_em] http error requesting #{url} / http.error: #{http.error} / http.response_header: #{http.response_header} / http.response: #{http.response} // RETRYING: tries_left: #{tries_left}, sleep_time: #{sleep_time}")
          EventMachine::Synchrony.sleep(sleep_time)
          return get_page_with_em(url, tries_left-1, sleep_time*2)
        end
      end
      return {:response => http.response, :to_cache => true}

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
      scanner = StringScanner.new(doc)
      urls = []
      while html = scanner.scan_until(/ <iframe( |>)/)
        iframeline = scanner.scan_until(/<\/iframe>/)
        linkurl = nil
        regexes.each {|regex| linkurl = linkurl || iframeline[regex]}
        urls << linkurl
      end
      return {:urls => urls, to_cache => true}
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
