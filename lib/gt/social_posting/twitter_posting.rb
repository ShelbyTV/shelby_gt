module SocialPosting
  
  private
  
    class Twitter

      def initialize(user)
        raise ArgumentError, 'Must provide User' unless @user = user
        @twitter_auth = @user.authentications.select { |a| a.provider == 'twitter'  }.first
        raise ArgumentError, 'User must have twitter authentication' unless @twitter_auth
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
    
      private
    
        def twitter_client
          @client ||= Grackle::Client.new(:auth => {
              :type => :oauth,
              :consumer_key => Settings::Twitter.consumer_key, 
              :consumer_secret => Settings::Twitter.consumer_secret,
              :token => @twitter_auth.oauth_token, 
              :token_secret => @twitter_auth.oauth_secret
            })
        end
      
    end
  
end