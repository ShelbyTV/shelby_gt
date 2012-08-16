require "api_clients/twitter_client"

module SocialPosting

    class Twitter<APIClients::TwitterClient

      def initialize(user)
        self.setup_for_user user
      end

      def post_tweet(message, in_reply_to_tweet_id=nil)
        opts = { :status => message } #XXX Do we need to truncate the message?
        opts[:in_reply_to_status_id] = in_reply_to_tweet_id if in_reply_to_tweet_id
        if Settings::Twitter.should_send_tweet
          return !!twitter_client.statuses.update!(opts)
        else
          Rails.logger.info "In production, would have tweeted: #{opts}"
          return true
        end
      end

    end

end