require 'open_graph'

module SocialPosting

  private
    
    class Facebook
    
      def initialize(user)
        raise ArgumentError, 'Must provide User' unless @user = user
        @facebook_auth = @user.authentications.select { |a| a.provider == 'facebook'  }.first
        raise ArgumentError, 'User must have facebook authentication' unless @facebook_auth
      end
      
      def post_comment(message, fb_post_id=nil, entity=nil)
        if Settings::Facebook.should_send_post
          # once our share action and roll object are approved by facebook, this will simplify to:
          # return !!GT::OpenGraph.send_action('share', @user, {:roll => entity, :message => message})

          # send OG action to FB
          ShelbyGT_EM.next_tick { GT::OpenGraph.send_action('share', @user, entity, message) }
          
          if entity.is_a? Roll            
            return !!facebook_client.put_object("me","feed",{
              :message => message, 
              :link => entity.short_links[:facebook],
              :picture => entity.thumbnail_url,
              :name => entity.title,
              :caption => "via Shelby.TV",
              :description => entity.title,
              :application => Settings::Facebook.app_name,
              :icon => Settings::Facebook.fb_application_icon
              })
          elsif entity.is_a? Frame
            return !!facebook_client.put_object("me","feed",{
              :message => message, 
              :link => entity.short_links[:facebook],
              :picture => entity.video.thumbnail_url,
              :name => entity.video.title,
              :caption => "via Shelby.TV",
              :description => entity.video.description,
              :application => Settings::Facebook.app_name,
              :icon => Settings::Facebook.fb_application_icon
              })
          else
            return !!facebook_client.put_object("me", "feed", {
              :message => message,
              :attribution => Settings::Facebook.app_name
              })
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