module APIClients
  class Vimeo
    
    def self.search(query, opts)
      raise ArgumentError, "must supply valid query" unless query.is_a?(String)
      
      return {:status => "ok", :limit => limit, :page => page, :videos => [] } if Rails.env == "test"
      
      limit = 10 unless opts[:limit]
      page = 1 unless opts[:page]
      converted = true unless opts[:converted]
      
      response = client.search(query, { :page => page, :per_page => limit.to_s, :full_response => "1", :sort => "relevant" })
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
          
          massaged_vid = {}
          massaged_vid[:provider_name] = "vimeo"
          massaged_vid[:provider_id] = vid["id"]
          massaged_vid[:title] = vid["title"]
          massaged_vid[:description] = vid["description"]
          massaged_vid[:duration] = vid["duration"]
          massaged_vid[:author] = vid["owner"]
          massaged_vid[:video_height] = vid["height"]
          massaged_vid[:video_width] = vid["width"]
          massaged_vid[:thumbnail_url] = thumbnail["_content"]
          massaged_vid[:thumbnail_height] = thumbnail["height"]
          massaged_vid[:thumbnail_width] = thumbnail["width"]
          massaged_vid[:tags] = tags
          massaged_vid[:source_url] = source_url
          massaged_vid[:embed_url] = embed_url
          massaged_vid[:view_count] = vid["number_of_plays"]
          massaged_vid[:favorite_count] = vid["number_of_favorites"]
          
          converted_videos << massaged_vid
        end
        return converted_videos
      end
    
  end
end