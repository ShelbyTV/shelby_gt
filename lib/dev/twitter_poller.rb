require 'video_manager'
require 'twitter_normalizer'
require 'social_sorter'

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
      client = twitter_client(twitter_auth.oauth_token, twitter_auth.oauth_secret)
            
      # Hit twitter, and process each tweet
      each_tweet_on_timeline(client, Settings::Twitter.dev_poller_tweets_per_page, Settings::Twitter.dev_poller_last_page) do |tweet|

        # find vids, and if there are any, have SocialSorter put them in their place...
        URI.extract(tweet.text, ["http", "https"]).each do |url|
          
          vids = GT::VideoManager.get_or_create_videos_for_url(url)
          msg = GT::TwitterNormalizer.normalize_tweet(grackle_to_hash(tweet))

          vids.empty? ? print(".") : puts("\nFound vids #{vids} for msg #{msg.inspect} (url #{url})")
          
          vids.each { |v| GT::SocialSorter.sort(msg, v, u) }

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
    
      def self.twitter_client(oauth_token, oauth_secret)
        Grackle::Client.new(:auth => {
            :type => :oauth,
            :consumer_key => Settings::Twitter.consumer_key, :consumer_secret => Settings::Twitter.consumer_secret,
            :token => oauth_token, :token_secret => oauth_secret
          })
      end
    
  end
end