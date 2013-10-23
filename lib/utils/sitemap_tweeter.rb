# encoding: utf-8
require "api_clients/twitter_client"
require "nokogiri"
require "zlib"

module Dev
  class SitemapTweeter < APIClients::TwitterClient

    def initialize(user, sitemap_number, options)
      @sitemap_number = sitemap_number
      @user = user #off shelby is: 4e55654cf6db241c220003c2
      @sleep_time = 20
      @limit = options['limit'] if options.has_key? :limit
      @box = options['box'] if options.has_key? :box
    end

    def tweet_urls
      setup_for_user(@user)
      sitemap_file_location = "/home/gt/#{@box ? @box : 'api'}/current/public/system/sitemap#{@sitemap_number}.xml.gz"
      i = 0
      begin
        Zlib::GzipReader.open(sitemap_file_location) { |gz|
          @f = gz.read
        }
        doc = Nokogiri::XML(@f)
      rescue => e
        Rails.logger.error "[SitemapTweeter] Error loading xml into Nokogiri. #{e}"
      end

      doc.css('urlset url').each do |n|
        return if @limit and (i > @limit)
        url = n.child.text
        url_frag = url.split('/')
        video_provider = url_frag[4]
        video_id = url_frag[5]
        # get video from shelby
        if video_provider and video_id and shelby_video = Video.first(:provider_name => video_provider, :provider_id => video_id)
          video_permalink = shelby_video.permalink
          video_title = shelby_video.title
          # tweet from offshelby about video
          tweet_text = video_title + " ▶ " + video_permalink
          begin
            tweet = twitter_client.statuses.update! :status => tweet_text
            puts tweet_text if tweet
          rescue => e
            Rails.logger.error "[SitemapTweeter] Error posting to Twitter. #{e}"
          end
        end
        sleep @sleep_time
        i += 1
      end
    end

  end
end
