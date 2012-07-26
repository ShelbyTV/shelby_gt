# encoding: UTF-8
require 'predator_manager'

module GT
  class AuthenticationBuilder
   
    # Takes an omniauth response and bulds a new authentication
    # - returns the new authentication
    def self.build_from_omniauth(omniauth)
      raise ArgumentError, "Must have credentials and user info" unless (omniauth.has_key?('credentials') and omniauth.has_key?('info'))

      auth = Authentication.new(
        :provider => omniauth['provider'],
        :uid => omniauth['uid'],
        :name => omniauth['info']['name'])

      #Optional credentials
      if omniauth['credentials']
        auth.oauth_token = omniauth['credentials']['token']
        auth.oauth_secret = omniauth['credentials']['secret'] if omniauth['credentials']['secret']
      end

      # Optional user info
      auth.nickname = omniauth['info']['nickname'] if omniauth['info']['nickname']
      auth.email = omniauth['info']['email'] if omniauth['info']['email']
      auth.first_name = omniauth['info']['first_name'] if omniauth['info']['first_name']
      auth.last_name = omniauth['info']['last_name'] if omniauth['info']['last_name']
      auth.location = omniauth['info']['location'] if omniauth['info']['location']
      auth.description = omniauth['info']['description'] if omniauth['info']['description']
      auth.image = omniauth['info']['image'] if omniauth['info']['image']
      auth.phone = omniauth['info']['phone'] if omniauth['info']['phone']
      auth.urls = omniauth['info']['urls'] if omniauth['info']['urls']

      # Extra user hash (from services like twitter)
      if omniauth['extra']
        auth.user_hash = omniauth['extra']['user_hash'] if omniauth['extra']['user_hash']      
        if omniauth['provider'] == 'facebook' and omniauth['extra']['user_hash']
          #from FB
          auth.email = omniauth['extra']['user_hash']['email'] if omniauth['extra']['user_hash']['email']
          auth.first_name = omniauth['extra']['user_hash']['first_name'] if omniauth['extra']['user_hash']['first_name']
          auth.last_name = omniauth['extra']['user_hash']['last_name'] if omniauth['extra']['user_hash']['last_name']
          auth.gender = omniauth['extra']['user_hash']['gender'] if omniauth['extra']['user_hash']['gender']
          auth.timezone = omniauth['extra']['user_hash']['timezone'] if omniauth['extra']['user_hash']['timezone']
          # request additional info from fb graph api
          auth.image = "http://graph.facebook.com/" + omniauth['uid'] + "/picture"

          graph = Koala::Facebook::GraphAPI.new(omniauth['credentials']['token'])
          begin
            auth.permissions = graph.get_connections("me","permissions")
          rescue Koala::Facebook::APIError => e
            Rails.logger.error "[Authentication ERROR] error with getting permissions: #{e}"
          end
        end
      end

      if omniauth['provider'] == 'tumblr' and omniauth['user_hash']
        auth.user_hash = omniauth['user_hash']
        auth.nickname = omniauth['user_hash']['name'] if omniauth['user_hash']['name']
        auth.name = omniauth['user_hash']['title'] if omniauth['user_hash']['title']
        auth.image = omniauth['user_hash']['avatar_url'] if omniauth['user_hash']['avatar_url']
      end

      return auth
    end
    
    # Takes facebook info and bulds a new authentication
    # - returns the new authentication
    def self.build_from_facebook(fb_info, token, fb_permissions)
      auth = Authentication.new(
        :provider => 'facebook',
        :uid => fb_info["id"],
        :oauth_token => token
      )

      # Optional user info
      auth.nickname = fb_info["username"] if fb_info["username"]
      auth.email = fb_info["email"] if fb_info["email"]
      auth.first_name = fb_info["first_name"] if fb_info["first_name"]
      auth.last_name = fb_info["last_name"] if fb_info["last_name"]
      auth.location = fb_info["timezone"] if fb_info["timezone"]
      auth.gender = fb_info["gender"] if fb_info["gender"]
      auth.description = fb_info["description"] if fb_info["description"]
      auth.image = "http://graph.facebook.com/" + fb_info["id"] + "/picture"

      auth.permissions = fb_permissions

      return auth
    end

    def self.normalize_user_info(u, auth)
      u.user_image = auth.image if !u.user_image and auth.image
      
      #If auth is twitter, we can try removing the _normal before the extension of the image to get the large version...
      if !u.user_image_original and auth.twitter? and !auth.image.blank? and !auth.image.include?("default_profile")
        u.user_image_original = auth.image.gsub("_normal", "")
      end
      
      u.primary_email = auth.email if u.primary_email.blank? and !auth.email.blank?
      
      if u.name.blank?
        u.name = auth.name
        u.name = "#{auth.first_name} #{auth.last_name}" if auth.first_name
      end
    end

    # Finds a users authentication and updates it
    #  - returns the updated auth
    def self.update_authentication_tokens!(u, provider, uid, credentials_token, credentials_secret)
      auth = authentication_by_provider_and_uid(u, provider, uid)
      return auth ? update_oauth_tokens!(u, auth, credentials_token, credentials_secret) : false
    end
    
    private
    
      # Updates oauth tokens for a users auth given an authentication
      #  - returns the updated auth
      def self.update_oauth_tokens!(u, a, credentials_token, credentials_secret)
        if a.oauth_token != credentials_token or a.oauth_secret != credentials_secret
          a.update_attributes!({ :oauth_token => credentials_token, :oauth_secret => credentials_secret })

          #and need the node processes to update as well
          GT::PredatorManager.update_video_processing(u, a)
        end
        return a
      end
    
      # Finds a auth by provider and id
      def self.authentication_by_provider_and_uid(u, provider, uid)
        u.authentications.select { |a| a.provider == provider and a.uid == uid } .first
      end
    
  end
end
