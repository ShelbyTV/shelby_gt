module APIClients
  class Youtube
    
    def self.search(query, opts)
      raise ArgumentError, "must supply valid query" unless query.is_a?(String)
      
      limit = opts[:limit] ? opts[:limit] : 10
      page = opts[:page] ? opts[:page] : 1
      converted = opts[:converted] ? opts[:converted] : true
      
      return {:status => "ok", :limit => limit, :page => page, :videos => [] } if Rails.env == "test"
      
      response = client.videos_by(:query => query, :page => page, :per_page => limit, :order_by => "relevance")
      
      if response.total_result_count > 0
        
        if converted
          videos = youtube_to_shelby_video_conversion(response.videos)
        else
          videos = response.videos.collect! {|v| v.as_json}
        end
        
        return {  :status => "ok",
                  :limit => limit,
                  :page => page,
                  :videos => videos
                }
      else
        return { :status => "no videos", :videos => [] }
      end
    end
    
    private
    
      def self.client
        unless @client
          @client = YouTubeIt::Client.new(:dev_key => Settings::Youtube.developer_key)
        end
        @client
      end
    
      def self.youtube_to_shelby_video_conversion(videos)
        converted_videos = []
        videos.each do |vid|
          
          # get the best version of the thumbnail if possible
          vid.thumbnails.each do |t|
            @thumbnail = t.url if t.width == 480
          end
          @thumbnail = vid.thumbnails.first.url unless @thumbnail
          
          # get categories as an array
          categories = []
          vid.categories.each do |v|
            categories << v.label
          end
          
          massaged_vid = {}
          massaged_vid[:provider_name] = "youtube"
          massaged_vid[:provider_id] = vid.unique_id
          massaged_vid[:title] = vid.title
          massaged_vid[:description] = vid.description
          massaged_vid[:duration] = vid.duration
          massaged_vid[:author] = vid.author.name
          massaged_vid[:thumbnail_url] = @thumbnail
          massaged_vid[:categories] = categories
          massaged_vid[:source_url] = vid.player_url
          massaged_vid[:embed_url] = vid.embed_html5
          massaged_vid[:view_count] = vid.view_count
          massaged_vid[:favorite_count] = vid.favorite_count
          
          converted_videos << massaged_vid
        end
        return converted_videos
      end
    
  end
end