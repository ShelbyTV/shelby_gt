# encoding: UTF-8

# Users are created/updated based on the info gathered from service API's via Omniauth.
# But sometimes we want that info outside of the Omniauth process.
#
# This utility gets the same info and puts it into a compatible format so we can pass it around in the same way.
#
module GT
  class ImposterOmniauth
    
    def self.get_user_info(provider, uid, token, secret=nil)
      case provider
      when "twitter" then return self.user_info_for_twitter(uid, token, secret)
      when "facebook" then return self.user_info_for_facebook(uid, token)
      else return {}
      end
    end
    
    def self.user_info_for_twitter(uid, oauth_token, oauth_secret)
      return {} unless (creds = self.get_twitter_user_info(oauth_token, oauth_secret))
      
      #omniauth compatible hash  
      h = {'provider' => 'twitter', 'uid' => uid, 'credentials' => {}, 'info' => {}}
      
      #--credentials
      h['credentials']['token'] = oauth_token
      h['credentials']['secret'] = oauth_secret
      
      #--standard info
      h['info']['nickname'] = creds.screen_name
      h['info']['name'] = creds.name
      h['info']['location'] = creds.location
      h['info']['image'] = creds.profile_image_url
      h['info']['description'] = creds.description
      
      return h
    end
    
    def self.user_info_for_facebook(uid, oauth_token)
      return {} unless (me = self.get_facebook_user_info(oauth_token))
      
      #omniauth compatible hash
      h = {'provider' => 'facebook', 'uid' => uid, 'credentials' => {}, 'info' => {}, 'extra' =>{'user_hash' => {}}}
      
      #--credentials
      h['credentials']['token'] = oauth_token
      
      #--standard info
      h['info']['nickname'] = me['username']
      h['info']['name'] = me['name']
      h['info']['location'] = (me['location'] || {})['name']
      h['info']['image'] = "http://graph.facebook.com/#{uid}/picture?type=square"
      h['info']['description'] = me['bio']
      
      #--additional FB stuff
      h['info']['email'] = me['email']
      h['info']['first_name'] = me['first_name']
      h['info']['last_name'] = me['last_name']
      
      #--extra user FB stuff
      h['extra']['user_hash']['gender'] = me['gender']
      h['extra']['user_hash']['timezone'] = me['timezone']
      
      return h
    end
    
    private
    
      def self.get_twitter_user_info(oauth_token, oauth_secret)
        c = Grackle::Client.new(:auth => {
            :type => :oauth,
            :consumer_key => Settings::Twitter.consumer_key, :consumer_secret => Settings::Twitter.consumer_secret,
            :token => oauth_token, :token_secret => oauth_secret
          })
        begin
          return c.account.verify_credentials?
        rescue Grackle::TwitterError => e
          return nil
        end
      end
      
      def self.get_facebook_user_info(oauth_token)
        graph = Koala::Facebook::API.new(oauth_token)
        begin
          me = graph.get_object "me"
        rescue Koala::Facebook::APIError => e
          return {}
        end
      end
    
  end
end
