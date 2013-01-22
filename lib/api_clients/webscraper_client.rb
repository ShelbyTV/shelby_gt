require 'embedly_regexes'
require 'url_helper'
require "url_video_detector"

module APIClients
  class WebScraper

    def self.get(query, opts)
      raise ArgumentError, "must supply a url" unless query.is_a?(String)

      limit = opts[:limit] ? opts[:limit] : 10
      page = opts[:page] ? opts[:page] : 1
      converted = opts[:converted] ? opts[:converted] : true

      return {:status => "ok", :limit => limit, :page => page, :videos => [] } if Rails.env == "test"

      begin
        urls = scrape_for_video_urls(query)
        video_meta_info = get_meta_info_for_videos(urls)
        videos = web_to_shelby_video_conversion(video_meta_info)
      rescue => e
        return { :status => 'error', :videos => [], :msg => e }
      end

      if videos
        return {  :status => "ok",
                  :limit => limit,
                  :page => page,
                  :videos => videos
              }
      else
        return { :status => 'error', :videos => [], :msg => e }
      end
    end

    private

      def self.scrape_for_video_urls(query)
        html = Nokogiri::HTML(open(query))
        hrefs = []
        ["a", "iframe", "embed", "object"].each do |e|
          links = html.css(e)
          ["href", "src"].each do |f|
            hrefs << links.map {|link| link.attribute(f).to_s}.uniq.sort.delete_if { |href| href.empty? || !Embedly::Regexes.video_regexes_matches?(href) }
          end
        end
        hrefs.flatten!
      end

      def self.get_meta_info_for_videos(urls)
        video_hashes = []
        urls.each do |url|
          vid_info = GT::UrlVideoDetector.examine_url_for_video(url)
          video_hashes << vid_info.first[:embedly_hash]
        end
        return video_hashes
      end

      def self.web_to_shelby_video_conversion(videos)
        converted_videos = []
        videos.each do |vid|
          # Determine provider name and id
          if (provider_info = GT::UrlHelper.parse_url_for_provider_info(vid['url'])) or
              (provider_info = GT::UrlHelper.parse_url_for_provider_info(vid['html'])) or
              (provider_info = GT::UrlHelper.parse_url_for_provider_info(vid['thumbnail_url']))
            provider_name = provider_info[:provider_name]
            provider_id = provider_info[:provider_id]
          else
            return nil
          end

          v = {}
          v['provider_name'] = provider_name
          v['provider_id'] = provider_id
          v['title'] = vid['title']
          v['name']= vid['name']
          v['description'] = vid['description']
          v['author'] = vid['author_name']
          v['video_height'] = vid['height']
          v['video_width'] = vid['width']
          v['thumbnail_url'] = vid['thumbnail_url']
          v['thumbnail_height'] = vid['thumbnail_height']
          v['thumbnail_width'] = vid['thumbnail_width']
          v['source_url'] = vid['url']
          v['embed_url'] = vid['html']

          converted_videos << v
        end
        return converted_videos
      end

  end
end