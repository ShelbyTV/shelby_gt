module APIClients
  class Youtube
    
    def self.search(query, limit=10, page=1, converted=true)
      raise ArgumentError, "must supply valid query" unless query.is_a?(String)
      
      return {:status => "ok", :limit => limit, :page => page, :videos => [] } if Rails.env == "test"
      
      response = client.videos_by(:query => query, :page => page, :per_page => limit)
      
      response = client.search("query", { :query => "timelapse", :page => page, :per_page => limit.to_s, :full_response => "1", :sort => "relevant" })
      if response["stat"] == "ok"
        
        if converted
          videos = vimeo_to_shelby_video_conversion(response["videos"]["video"])
        else
          videos = response["videos"]["video"]
        end
        
        return {  :status => response["stat"],
                  :limit => limit,
                  :page => page,
                  :videos => response["videos"]["video"]
                }
      else
        return { :status => response["stat"] }
      end
    end
    
    private
    
      def self.client
        unless @client
          @client = YouTubeIt::Client.new(:dev_key => Settings::Youtube.developer_key)
        end
        @client
      end
    
    
  end
end