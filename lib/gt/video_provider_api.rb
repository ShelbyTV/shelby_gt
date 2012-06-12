require 'youtube_it'
require 'net/http'
require 'nokogiri'

module GT
  class VideoProviderApi
    def self.examine_url_for_youtube_video(youtube_id, use_em=true)
      gdata_url = "http://gdata.youtube.com/feeds/api/videos/#{youtube_id}"
      if use_em
        youtube_http = get_page_with_em(gdata_url)
      else
        youtube_http = get_page_with_net(gdata_url)
      end

      return nil unless youtube_http
      # pretty sure this doesn't make an http request 
      begin
        parser = YouTubeIt::Parser::VideoFeedParser.new(youtube_http)
      #if the page does not have an entry element
      rescue NoMethodError => e
        return nil
      end 
      # a youtube it video object
      return get_or_create_videos_for_yt_model(parser.parse)
      

    end
      
    private

      def self.get_or_create_videos_for_yt_model(yt_model)

        v  = Video.new
        v.provider_name = "youtube"
        v.provider_id = yt_model.unique_id
        v.title = yt_model.title
        v.description = yt_model.description
        v.duration = yt_model.duration
        v.author = yt_model.author.name
        if yt_model.thumbnails && yt_model.thumbnails.length > 0
          yt_thumbnail = yt_model.thumbnails[0]
          v.thumbnail_url = yt_thumbnail.url
          v.thumbnail_height = yt_thumbnail.height
          v.thumbnail_width = yt_thumbnail.width
        end
        v.categories = yt_model.categories.map {|category| category.label}
        v.source_url = yt_model.player_url
        v.embed_url = yt_model.embed_url

        begin
          v.save
          return v
        rescue Mongo::OperationFailure => e
          # If this was a timing issue, and Video got created after we checked, that means the Video exists now.  See if we can't recover...
          v = Video.where(:provider_name => provider_name, :provider_id => provider_id).first
          return v if v
          Rails.logger.error "[GT::VideoManager#find_or_create_video_for_embedly_hash] rescuing Mongo::OperationFailure #{e}"
          return nil
        end
      end



      def self.get_page_with_em(url, tries_left=5, sleep_time=2)
        http = EventMachine::HttpRequest.new(url, :connect_time => 5).get
        if http.response_header and http.response_header.status == 404
          return nil
        end

        if http.error or http.response_header.status != 200
          if tries_left <= 0
            return nil
          else
            return get_page_with_em(url, tries_left - 1, sleep_time * 2)
          end
        end
        return http.response
      end

      def self.get_page_with_net(url)
        begin
          response = Net::HTTP.get_response(URI.parse(url))
        ensure
          return nil unless response
        end

        if response.code == "200"
          return response.body
        elsif response.code == "404"
          return nil
        else
          return nil
        end
      end
  end
end

