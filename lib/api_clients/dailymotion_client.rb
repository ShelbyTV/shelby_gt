module APIClients
  class Dailymotion
    include HTTParty
    base_uri "https://api.dailymotion.com"

    def self.search(query, opts)
      raise ArgumentError, "must supply valid query" unless query.is_a?(String)

      limit = opts[:limit] ? opts[:limit] : 10
      page = opts[:page] ? opts[:page] : 1
      converted = opts[:converted] ? opts[:converted] : true

      return {:status => "ok", :limit => limit, :page => page, :videos => [] } if Rails.env == "test"

      begin
        response = get('/videos',
                      :query => { :search => query,
                                  :sort => "relevance",
                                  :limit => limit.to_s,
                                  :page => page.to_s,
                                  :fields => "id,title,description,duration,embed_url,embed_html,thumbnail_url,url,views_total,tags"})

      rescue => e
        return { :status => 'error', :videos => [], :msg => e }
      end

      if response["total"] and response["total"] > 0

        if converted
          videos = dailymotion_to_shelby_video_conversion(response["list"])
        else
          videos = response["list"]
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

      def self.dailymotion_to_shelby_video_conversion(videos)
        converted_videos = []
        videos.each do |vid|

          massaged_vid = {}
          massaged_vid[:provider_name] = "dailymotion"
          massaged_vid[:provider_id] = vid["id"]
          massaged_vid[:title] = vid["title"]
          massaged_vid[:description] = vid["description"]
          massaged_vid[:duration] = vid["duration"]
          massaged_vid[:thumbnail_url] = vid["thumbnail_url"]
          massaged_vid[:tags] = vid["tags"]
          massaged_vid[:source_url] = vid["url"]
          massaged_vid[:embed_url] = vid["embed_html"]
          massaged_vid[:view_count] = vid["views_total"]

          converted_videos << massaged_vid
        end
        return converted_videos
      end

  end
end