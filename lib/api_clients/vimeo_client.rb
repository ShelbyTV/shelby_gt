module APIClients
  class Vimeo
    
    def self.search(query, limit=10, page=1, converted=true)
      raise ArgumentError, "must supply valid query" unless query.is_a?(String)
      
      return {:status => "ok", :limit => limit, :page => page, :videos => [] } if Rails.env == "test"
      
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
                  :videos => videos
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
      
      def self.vimeo_to_shelby_video_conversion(videos)
        converted_videos = []
        videos.each do |vid|
          
          thumbnail = vid["thumbnails"]["thumbnail"].last if vid["thumbnails"]
          embed_url = "<iframe src='http://player.vimeo.com/video/"+vid["id"]+"' width='500' height='281' frameborder='0' webkitAllowFullScreen mozallowfullscreen allowFullScreen></iframe>"
          source_url = vid["urls"]["url"].first["_content"] if (vid["urls"] and vid["urls"]["url"])
          tags = vid["tags"]["tag"] if vid["tags"]
          
          massaged_vid = {
            :provider_name => "vimeo",
            :provider_id => vid["id"],
            :title => vid["title"], 
            :description => vid["description"],
            :duration => vid["duration"],
            :author => vid["owner"],
            :video_height => vid["height"],
            :video_width => vid["width"],
            :thumbnail_url => thumbnail["_content"],
            :thumbnail_height => thumbnail["height"], 
            :thumbnail_width => thumbnail["width"],
            :tags => tags,
            :source_url => source_url,
            :embed_url => embed_url
          }
          converted_videos << massaged_vid
        end
        converted_videos
      end
    
  end
end