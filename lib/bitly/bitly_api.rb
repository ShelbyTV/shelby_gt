module Bitly
  class API
    
    def self.get_shorten_call(url)
      "http://api.bitly.com/v3/shorten?longUrl="+ CGI.escape(url) +"&login="+ Settings::Bitly.api_username +"&apiKey=" + Settings::Bitly.api_key
    end
    
    def self.do_single_threaded_shorten!(url)
      shortlink = nil
      
      uri = URI.parse(get_shorten_call(url))
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Get.new(uri.request_uri)
      response = http.request(request)
    
      if "200" == response.code
        begin
          json_resp = JSON.parse(response.body)
          
          if( json_resp["status_code"] == 200 and !json_resp['data'].empty? )
            return json_resp['data']['url'] #return shortlink
          else
            Rails.logger.error( "[Bitly::API.do_single_threaded_shorten] ERROR: did not return 200. -- url to shorten: #{url} -- request uri: #{uri} -- -- response.body #{response.body} -- response.body parsed: #{json_resp}" )
            return nil
          end
        rescue => e
          Rails.logger.error( "[Bitly::API.do_single_threaded_shorten] ERROR: #{e} -- url to shorten: #{url} -- request uri: #{uri} -- response: #{response} -- response.body #{response.body} -- response.body parsed: #{json_resp} -- BACKTRACE: #{e.backtrace.join('\n')}" )
        end
      end  
      
      return nil
    end
    
    
  end
end