require 'video_manager'
require 'twitter_normalizer'
require 'social_sorter'
require 'api_clients/twitter_client'

# So, you want some fresh data from our Twitter stream?
# Just run Dev::TwitterPoller.poll_for_user(your_user) to scrape as far back in your home timeline as twitter will let us.
#
# ** Polling is idempotent.  Run it as much as you'd like.  Results should be exactly the same as Arnold (only slower). **
#
module Dev
  class TwitterPoller

    # Idempotent.  You can run this as much as you like, there won't be duplicates.
    def self.poll_for_user(u)
      raise ArgumentError, "must present a User" unless u.is_a?(User)
      raise ArgumentError, "User doesn't have a twitter auth" unless twitter_auth = u.authentications.select { |a| a.provider == 'twitter'  }.first
      client = APIClients::TwitterClient.build_for_token_and_secret(twitter_auth.oauth_token, twitter_auth.oauth_secret)

      # Hit twitter, and process each tweet
      each_tweet_on_timeline(client, Settings::Twitter.dev_poller_tweets_per_page, Settings::Twitter.dev_poller_last_page) do |tweet|

        # find vids, and if there are any, have SocialSorter put them in their place...
        URI.extract(tweet.text, ["http", "https"]).each do |url|
          puts "[TWEET] url: #{url}"
          vids_hash = GT::VideoManager.get_or_create_videos_for_url(url)
          puts "[TWEET] vids_hash: #{vids_hash}"
          msg = GT::TwitterNormalizer.normalize_tweet(grackle_to_hash(tweet))
          puts "[TWEET] msg: #{msg.inspect}"
          #vids_hash.empty? ? print(".") : puts("\nFound vids #{vids_hash} for msg #{msg.inspect} (url #{url})")

          unless vids_hash.empty?
            vids_hash[:videos].each { |v| puts "[TWEET] sorted: #{GT::SocialSorter.sort(msg, {:video=>v}, u)}" }
          end

        end

      end # /each_tweet_on_timline

    end

    private

      def self.each_tweet_on_timeline(client, per_page, last_page, &block)
        begin
          #Grab users's own tweets
          #currently limited to 3,200 or 16 pages (1-17) of 200 tweets/page
          cur_page = 1
          while cur_page <= last_page
            statuses = client.statuses.home_timeline? :count => per_page, :page => cur_page
            puts "just grabbed page #{cur_page} of tweets"
            cur_page += 1
            break if statuses.empty?
            statuses.each { |s| yield(s) }
          end

        rescue Grackle::TwitterError => twit_err
          puts "error pulling from twitter via Gracke: #{twit_err.to_s}"
        end
      end

      def self.grackle_to_hash(g)
        tweet = JSON.parse(g.to_json)["table"]
        tweet["user"] = tweet["user"]["table"]
        return tweet
      end

  end
end
