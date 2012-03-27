module SocialPosting

  private
    
    class Facebook
    
      def initialize(user)
        raise ArgumentError, 'Must provide User' unless @user = user
        @facebook_auth = @user.authentications.select { |a| a.provider == 'facebook'  }.first
        raise ArgumentError, 'User must have facebook authentication' unless @facebook_auth
      end
      
      def post_comment(message, fb_post_id=nil, frame=nil)
        if Settings::Facebook.should_send_post
          if fb_post_id
            return !!facebook_client.put_comment(fb_post_id, {
              :message => message, 
              :attribution => Settings::Facebook.app_name
              })
          else
            if frame
              return !!facebook_client.put_object("me","feed",{
                :message => message, 
                :link => frame.permalink,
                :picture => frame.video.thumbnail_url,
                :name => frame.video.title,
                :caption => "via Shelby.TV",
                :description => frame.video.description,
                :application => Settings::Facebook.app_name,
                :icon => Settings::Facebook.fb_application_icon
                })
            else
              return !!facebook_client.put_object("me", "feed", {
                :message => message,
                :attribution => Settings::Facebook.app_name
                })
            end
          end
        else
          Rails.logger.info "In production, would have facebooked: #{message} w/ post_id #{fb_post_id}"
          return true
        end
      end    

      private
    
        def facebook_client
          @facebook_client ||= Koala::Facebook::GraphAPI.new(@facebook_auth.oauth_token)
        end
    end

end