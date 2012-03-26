module SocialPosting
  
  private
  
    class Tumblr
      
      def initialize(user)
        raise ArgumentError, 'Must provide User' unless @user = user
        @tumblr_auth = @user.authentications.select { |a| a.provider == 'tumblr'  }.first
        raise ArgumentError, 'User must have tumblr authentication' unless @tumblr_auth
      end
      
      #TODO: we need an iframe player for gt before we can post to tumblr!
      def post_video(comment, bcast_id)
        return false if Settings::Tumblr.should_send_to_tumblr
=begin
        bcast = Broadcast.find(bcast_id)
        access_token = OAuth::AccessToken.new(tumblr_client, @tumblr_auth.oauth_token, @tumblr_auth.oauth_secret)
        embed_code = '<iframe src="http://'+ APP_CONFIG[:domain] + '/#!/channels/' + bcast.channel_id.to_s + '/broadcasts/' + bcast_id.to_s + '" width="500" height="375" frameborder="0"></iframe>'
        post_url = 'http://www.tumblr.com/api/write'
        post_options = {:type => "video", :embed => embed_code, :caption => comment, :group => site_to_post_to(), :tags => "shelby.tv"}
        post = access_token.post(post_url, post_options)
=end
      end
      
      private
        
        def site_to_post_to
          url_match = (/(\/\/)([\w.]*)/i).match(@tumblr_auth['urls'])
          if url_match
            site = url_match[2] if url_match[2]
          else
            site = @tumblr_auth.uid + '.tumblr.com'
          end
          return site
        end
    
        def tumblr_client
          @tumblr_client ||= OAuth::Consumer.new(Settings::Tumblr.key], Settings::Tumblr.secret ,{:site => "http://www.tumblr.com"})
        end
      
    end
  
end