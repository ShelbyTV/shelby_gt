# encoding: UTF-8
require 'authentication_builder'
require 'video_fetching'


# This is the one and only place where Users are created.
#
# Used to create actual users (on signup) and faux Users (for public Roll)
#
module GT
  class UserManager
    
    # Creates a real User on signup
    def self.create_new_user_from_omniauth(omniauth)
      user, auth = build_new_user_and_auth(omniauth)
      
      if user.save
        GT::VideoFetching.initialize_video_processing(user, auth)
        
        # Update user count stat
        #Stats.increment(Stats::TOTAL_USERS)
        return user
      else
        puts user.errors.full_messages
        return user.errors
      end
    end
    
    # Things that happen when a user signs in.
    def self.start_user_sign_in(user, omniauth=nil)
      GT::AuthenticationBuilder.update_authentication_tokens!(user, omniauth) if omniauth
      update_on_sign_in(user)
      # Always remember users, onus is on them to log out
      user.remember_me!
    end
    
    # Adds a new auth to an existing user
    def self.add_new_auth_from_omniauth(user, omniauth)
      new_auth = GT::AuthenticationBuilder.build_from_omniauth(omniauth)
      user.authentications << new_auth
      if user.save
        GT::VideoFetching.initialize_video_processing(user, new_auth)        
        return user
      else
        puts user.errors.full_messages
        return false
      end
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
      #TODO DRY
      #TODO This is all common to new user, pull out into helper
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
      
      # Takes an omniauth hash to build one user, prefs, and an auth to go along with it
      def self.build_new_user_and_auth(omniauth)
        u = User.new

        u.nickname = omniauth['info']['nickname']
        u.nickname = omniauth['info']['name'] if u.nickname.blank? or u.nickname.match(/\.php\?/)

        u.name = omniauth['info']['name']

        auth = GT::AuthenticationBuilder.build_from_omniauth(omniauth)

        GT::AuthenticationBuilder.normalize_user_info(u, auth)
        ensure_valid_unique_nickname!(u)
        u.downcase_nickname = u.nickname.downcase

        u.authentications << auth

        #TODO: this is common to user creation, should not be in a specific method like this
        u.preferences = Preferences.new()
        
        return u, auth
      end
      
      # If we have an FB authentication, poll on demand... and get updated permissions
      #TODO: this needs a new name
      def self.update_on_sign_in(u)
        u.authentications.each do |a| 
          GT::VideoFetching.update_video_processing(u, a)
          if a.provider == "facebook"
            begin
              graph = Koala::Facebook::GraphAPI.new(a.oauth_token)
              fb_permissions = graph.get_connections("me","permissions")
              a['permissions'] = fb_permissions if fb_permissions
              u.save!
            rescue Koala::Facebook::APIError => e
              Rails.logger.error "ERROR with getting Facebook Permissions: #{e}"
            rescue => e
              Rails.logger.error "[GT::UserManager] ERROR saving user after updating: #{e}"
            end
          end
        end
      end
      
      # Makes sure a nickname is valid and unique!
      def self.ensure_valid_unique_nickname!(user)
        #replace whitespace with underscore
        user.nickname = user.nickname.gsub(' ','_');
        #remove punctuation
        user.nickname = user.nickname.gsub(/['‘’"`]/,'');
        
        orig_nick = user.nickname
        i = 2
        
        while( User.where( :downcase_nickname => user.nickname.downcase ).count > 0 ) do
          user.nickname = "#{orig_nick}_#{i}"
          i = i*2
        end
      end
      
    
  end
end