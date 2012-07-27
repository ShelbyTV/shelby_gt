require 'net/http'

module GT
  class DeeplinkParser
	
    DOMAIN_REGEX = /\w+\.\w+\/\w+/
    PROVIDER_REGEXES = [{
        "provider"=> "blip",
        "domain"=> "blip.tv",
        "regex"=> [/flash\/stratos\.swf/, /http:\/\/blip\.tv\/play\//],
        "url_regex"=> /([0-9]+)/
    }, {
        "provider"=> "brightcove",
        "domain"=> "brightcove.com",
        "regex"=> [/brightcove.com\/services\/viewer/]
    }, {
        "provider"=> "collegehumor",
        "domain"=> "collegehumor.com",
        "regex"=> [/videoid([0-9]+)/, /clip_id=([0-9]+)/],
        "url_regex" => /([0-9]+)/
    }, {
        "provider"=> "dailymotion",
        "domain"=> "dailymotion.com",
        "regex"=> [/videoId%22%3A%22([a-zA-Z0-9]+)/, /dailymotion.com%2Fvideo%2F([a-zA-Z0-9]+)_/, /dailymotion\.com\/embed\/video\/([a-zA-Z0-9]+)/, /dailymotion\.com\/swf\/([a-zA-Z0-9]+)/, /www.dailymotion.com\/video\/([a-zA-Z0-9]+)_/]
    }, {
        "provider"=> "hulu",
        "domain"=> "hulu.com",
        "regex"=> [/\/site-player\/(\d*)\/player/]
    }, {
        "provider"=> "pbs",
        "domain"=> "video.pbs.org",
        "regex"=> [/width=512&height=288&video=.*?\/([0-9]+)/]
    }, {
        "provider"=> "techcrunch",
        "domain"=> "techcrunch.tv",
        "regex"=> [/embedCode=(\w*)/]
    }, {
        "provider"=> "ted",
        "domain"=> "ted.com",
        "regex"=> [/&amp;su=(http:\/\/www\.ted\.com.*?\.html)&amp;/, /&su=(http:\/\/www\.ted\.com.*?\.html)&/, /vu=http:\/\/video\.ted\.com\/.*?&su/]
    }, {
        "provider"=> "vimeo",
        "domain"=> "vimeo.com",
        "scrape_url"=> "http:\/\/(?:\w+\.)*vimeo\.com\/([0-9]+)|http:\/\/(?:\w+\.)*vimeo\.com.*clip_id=([0-9]+)",
        "regex"=> [/vimeo\.com\/moogaloop\.swf\?clip_id=([0-9]+)/, /clip_id=([0-9]+)&server=vimeo\.com/, /clip_id=([0-9]+)/, /(player.vimeo.com\/video\/)(\d*)/, /(player)(\d*)/]
    }, {
        "provider"=> "youtube",
        "domain"=> "youtube.com",
        "scrape_url"=> "http:\/\/(?:\w+\.)*youtube\.com.*v=([\_\-a-zA-Z0-9]+)",
        "regex"=> [/&video_id=([a-zA-Z0-9]+)/, /youtube\.com\/v\/([a-zA-Z0-9]+)/, /youtube\-nocookie\.com\/v\/([a-zA-Z0-9]+)/, /youtube\.com\/embed\/([a-zA-Z0-9]+)/]
    }, {
        "provider"=> "bloomberg",
        "domain"=> "bloomberg.com",
        "regex"=> [/embedCode=(\w*)/]
    }, {
      "provider"=> "espn",
        "domain"=> "espn.com,espn.go.com",
        "regex"=> [/espn%3A([0-9]+)&/]
    }]

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
    end

    def self.get_page_with_net(url)
      begin
        response = Net::HTTP.get_response(url)
      ensure
        return {:response => nil, :to_cache => false} unless response
      end
    
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
      
      

    def self.deep_parse_url(url, use_em=true)
      if use_em
        deep_http_response = get_page_with_em(url)
      else
        deep_http_response = get_page_with_net(url)
      end
      if deep_response = deep_http_response[:response]
        parsedoc = Nokogiri::HTML(deep_response)
        embed_elements = []
        embed_elements += parsedoc.xpath("//iframe")
        embed_elements += parsedoc.xpath("//embed")
        embed_elements += parsedoc.xpath("//object")
        embed_elements += parsedoc.xpath("//video")
        urls = []
        for embed in embed_elements
            url = getVideoInfo(embed)
            urls << url if url
        end
        return {:urls => urls, :to_cache => true}
      end
      return {:urls => [], :to_cache => deep_http_response[:to_cache]}
    end

    def self.getElementValue(obj, id) 
        value = '';
        value += obj.xpath("@" + id).to_s
        obj.children.each do |child|
            if child.xpath(@name).first.value == id
                value += child.xpath(@value).first.value
            end
        end
        return value
    end

    def self.getVideoInfo(embedObj)
        str = "";
        str += getElementValue(embedObj, 'flashvars') + '&amp;' + getElementValue(embedObj, 'src') + getElementValue(embedObj, 'data') +
              getElementValue(embedObj, 'name') + embedObj.inner_html;
        for provider in PROVIDER_REGEXES
            for regex in provider["regex"]
              domains = provider["domain"].split(",")
              valid_domain = false
              video_domain = nil
              for domain in domains
                  domain_reg = Regexp.new(domain)
                  if domain_reg.match(str)
                      valid_domain = true
                      video_domain = domain
                      break
                  end
              end
              if valid_domain
              puts str
              puts regex
              end
              if match = regex.match(str) and valid_domain
                vid_id = match[2] || match[1]
                return composeKnownUrl(domain, vid_id)
              end
          end
        end
        return nil
    end
                  
                  

    def self.composeKnownUrl(domain, video_id) 
        known_url = nil
        case(domain)
        when 'blip.tv'
            known_url = "http://blip.tv/file/" + video_id
            
        when 'youtube.com'
            known_url = "http://www.youtube.com/watch?v=" + video_id
            
        when "dailymotion.com"
            known_url = "http://www.dailymotion.com/video/" + video_id + "?"
            
        when 'vimeo.com'
            known_url = "http://www.vimeo.com/" + video_id
            
        when 'techcrunch.tv'
            known_url = "http://techcrunch.tv/watch?id=" + video_id
            
        when 'collegehumor.com'
            known_url = "http://collegehmumor.com/video/" + video_id
            
        when 'espn.com,espn.go.com'
            known_url = "http://espn.go.com/video/clip?id=" + video_id
            
        end
        return known_url
    end
	
	
  end
end
