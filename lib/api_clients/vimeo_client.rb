module APIClients
  class Vimeo
    
    def self.search(query, limit=10, page=1)
      raise ArgumentError, "must supply valid query" unless query.is_a?(String)
      
      return {:status => "ok", :limit => limit, :page => page, :videos => [] } if Rails.env == "test"
      
      response = client.search("query", { :query => "timelapse", :page => page, :per_page => limit.to_s, :full_response => "1", :sort => "relevant" })
      if response["stat"] == "ok"
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
          @client = ::Vimeo::Advanced::Video.new(Settings::Vimeo.consumer_key, Settings::Vimeo.consumer_secret)
        end
        @client
      end
    
    
  end
end