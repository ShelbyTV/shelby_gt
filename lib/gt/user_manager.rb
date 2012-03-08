# encoding: UTF-8

# This is the one and only place where Users are created.
#
# Used to create actual users (on signup) and faux Users (for public Roll)
#
module GT
  class UserManager
    
    # Creates a real User on signup
    def self.create_new_from_omniauth(omniauth)
      u = User.new
      
      u.nickname = omniauth['user_info']['nickname']
      u.nickname = omniauth['user_info']['name'] if u.nickname.blank? or u.nickname.match(/\.php\?/)
      
      u.name = omniauth['user_info']['name']
      
      auth = build_authentication_from_omniauth(omniauth)

      fill_in_user_with_auth_info(u, auth)
      ensure_valid_unique_nickname!(u)
      
      u.authentications << auth

      return u
    end
    
    
    # Creates a fake User with an Authentication matching the given network and user_id
    #
    # --arguments--
    # nickname => REQUIRED the unclean nickname for this user
    # provider => REQUIRED the name of the fucking social network
    # uid => REQUIRED the id given to the user by the social network
    #
    # --returns--
    # a User - which may be an actual User or a faux User - with a public Roll
    # Or the Errors, if save failed.
    #
    def self.get_or_create_faux_user(nickname, provider, uid)
      u = User.first( :conditions => { 'authentications.provider' => provider, 'authentications.uid' => uid } )
      return u if u
      
      # No user (faux or real) existed, create a faux user...
      u = User.new
      u.nickname = nickname
      u.faux = true
      
      # This Authentication is how the user will be looked up...
      auth = Authentication.new(:provider => provider, :uid => uid, :nickname => nickname)
      u.authentications << auth
      
      ensure_valid_unique_nickname!(u)
      u.downcase_nickname = u.nickname.downcase
      
      # Create the public Roll for this new User
      r = Roll.new
      r.creator = u
      r.public = true
      r.collaborative = false
      r.title = u.nickname
      u.public_roll = r
      
      if u.save
        return u
      else
        puts u.errors.full_messages
        return u.errors
      end
    end
    
    
    # *******************
    # TODO UserManager needs to be DRY and SIMPLE!  After merging w/ the rest of user/auth creation, things will get messy.
    # TODO That's fine, at first.  Make sure it's well tested and the tests pass.
    # TODO When we know that everythings working, we refactor this shit out of this.
    # *******************
    
    # TODO: Going to need to handle faux User becoming *real* User
    
    private
      
      def self.build_authentication_from_omniauth(omniauth)
        raise ArgumentError, "Must have credentials and user info" unless (omniauth.has_key?('credentials') and omniauth.has_key?('user_info'))

        auth = Authentication.new(
          :provider => omniauth['provider'],
          :uid => omniauth['uid'],
          :name => omniauth['user_info']['name'])

        #Optional credentials
        if omniauth['credentials']
          auth.oauth_token = omniauth['credentials']['token']
          auth.oauth_secret = omniauth['credentials']['secret'] if omniauth['credentials']['secret']
        end

        # Optional user info
        auth.nickname = omniauth['user_info']['nickname'] if omniauth['user_info']['nickname']
        auth.email = omniauth['user_info']['email'] if omniauth['user_info']['email']
        auth.first_name = omniauth['user_info']['first_name'] if omniauth['user_info']['first_name']
        auth.last_name = omniauth['user_info']['last_name'] if omniauth['user_info']['last_name']
        auth.location = omniauth['user_info']['location'] if omniauth['user_info']['location']
        auth.description = omniauth['user_info']['description'] if omniauth['user_info']['description']
        auth.image = omniauth['user_info']['image'] if omniauth['user_info']['image']
        auth.phone = omniauth['user_info']['phone'] if omniauth['user_info']['phone']
        auth.urls = omniauth['user_info']['urls'] if omniauth['user_info']['urls']

        # Extra user hash (from services like twitter)
        if omniauth['extra']
          auth.user_hash = omniauth['extra']['user_hash'] if omniauth['extra']['user_hash']      
          if omniauth['provider'] == 'facebook'
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
      
      def self.fill_in_user_with_auth_info(u, auth)
        u.user_image = auth.image if !u.user_image and auth.image
        
        #If auth is twitter, we can try removing the _normal before the extension of the image to get the large version...
        if !u.user_image_original and auth.twitter? and !auth.image.blank? and !auth.image.include?("default_profile")
          u.user_image_original = auth.image.gsub("_normal", "")
        end
        u.primary_email = auth.email if u.primary_email.blank? and !auth.email.blank?
      end
      
      def self.ensure_valid_unique_nickname!(u)
        #replace whitespace with underscore
        u.nickname = u.nickname.gsub(' ','_');
        #remove punctuation
        u.nickname = u.nickname.gsub(/['‘’"`]/,'');
        
        orig_nick = u.nickname
        i = 2
        
        while( User.where( :downcase_nickname => u.nickname.downcase ).count > 0 ) do
          puts "makeing uniq!"
          u.nickname = "#{orig_nick}_#{i}"
          i = i*2
        end
      end
    

    
  end
end