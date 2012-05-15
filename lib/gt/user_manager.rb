# encoding: UTF-8
require 'authentication_builder'
require 'predator_manager'


# This is the one and only place where Users are created.
#
# Used to create actual users (on signup) and faux Users (for public Roll)
#
module GT
  class UserManager
    
    # Creates a real User on signup
    def self.create_new_user_from_omniauth(omniauth)
      user, auth = build_new_user_and_auth(omniauth)

      # build, don't save, public and watch_later rolls
      ensure_users_special_rolls(user)
      
      #additional meta-data for faux user public roll
      user.public_roll.origin_network = Roll::SHELBY_USER_PUBLIC_ROLL

      if user.save
        GT::PredatorManager.initialize_video_processing(user, auth)
        
        StatsManager::StatsD.increment(Settings::StatsConstants.user['new']['real'], user.id, 'signup')
        
        return user
      else
        
        StatsManager::StatsD.increment(Settings::StatsConstants.user['new']['error'])
        
        Rails.logger.error "[GT::UserManager#create_new_user_from_omniauth] Failed to create user: #{user.errors.full_messages.join(',')} / user looks like: #{user.inspect}"
        return user.errors
      end
    end
    
    # Things that happen when a user signs in.
    def self.start_user_sign_in(user, omniauth=nil, session=nil)
      GT::AuthenticationBuilder.update_authentication_tokens!(user, omniauth) if omniauth
      
      update_token_and_permissions(user)
      
      ensure_app_progress_created(user)
      
      # Always remember users, onus is on them to log out
      user.remember_me!(true)
    end
    
    # Adds a new auth to an existing user
    def self.add_new_auth_from_omniauth(user, omniauth)
      new_auth = GT::AuthenticationBuilder.build_from_omniauth(omniauth)
      user.authentications << new_auth
      if user.save
        GT::PredatorManager.initialize_video_processing(user, new_auth)        
        
        StatsManager::StatsD.increment(Settings::StatsConstants.user['add_service'][new_auth.provider], user.id, 'add_service')
        
        return user
      else
        StatsManager::StatsD.increment(Settings::StatsConstants.user['add_service']['error'])
                
        Rails.logger.error "[GT::UserManager#add_new_auth_from_omniauth] Failed to save user: #{user.errors.full_messages.join(',')}"
        return false
      end
    end
    
    # Creates a fake User with an Authentication matching the given network and user_id
    #
    # --arguments--
    # nickname => REQUIRED the unclean nickname for this user
    # provider => REQUIRED the name of the fucking social network
    # uid => REQUIRED the id given to the user by the social network
    # options => OPTIONAL accepts:
    #   :user_thumbnail_url => will set this on a newly created user, which will propagate to their special rolls as thumbnails
    #
    # --returns--
    # a User - which may be an actual User or a faux User - with a public Roll
    # Or the Errors, if save failed.
    #
    def self.get_or_create_faux_user(nickname, provider, uid, options = {})
      raise ArgumentError, "must supply valid nickname" unless nickname.is_a?(String) and !nickname.blank?
      raise ArgumentError, "must supply valid provider" unless provider.is_a?(String) and !provider.blank?
      raise ArgumentError, "must supply valid uid" unless uid.is_a?(String) and !uid.blank?
      
      if u = User.first( :conditions => { 'authentications.provider' => provider, 'authentications.uid' => uid } )
        ensure_users_special_rolls(u, true)
        return u
      end
      
      begin
        # No user (faux or real) existed, create a faux user...
        u = User.new
        u.server_created_on = "GT::UserManager#get_or_create_faux_user/#{nickname}/#{provider}/#{uid}"
        u.nickname = nickname
        u.user_image = u.user_image_original = options[:user_thumbnail_url]
        u.faux = User::FAUX_STATUS[:true]
        u.preferences = Preferences.new()
        u.app_progress = AppProgress.new()
        # This Authentication is how the user will be looked up...
        auth = Authentication.new(:provider => provider, :uid => uid, :nickname => nickname)
        u.authentications << auth
      
        ensure_valid_unique_nickname!(u)
        u.downcase_nickname = u.nickname.downcase
      
        ensure_users_special_rolls(u)

        #additional meta-data for faux user public roll
        u.public_roll.origin_network = provider
      
        if u.save
          StatsManager::StatsD.increment(Settings::StatsConstants.user['new']['faux'])
          return u
        else
          # If this was a timing issue, and User got created after we initially checked, that means the User we want exists now.  See if we can't recover...
          u2 = User.first( :conditions => { 'authentications.provider' => provider, 'authentications.uid' => uid } )
          return u2 if u2
          
          StatsManager::StatsD.increment(Settings::StatsConstants.user['new']['error'])
          Rails.logger.error "[GT::UserManager#get_or_create_faux_user] Failed to create user: #{u.errors.full_messages.join(',')} / user looks like: #{u.inspect}"
          return u.errors
        end
      rescue Mongo::OperationFailure => e
        # If this was a timing issue, and User got created after we initially checked, that means the User we want exists now.  See if we can't recover...
        EventMachine::Synchrony.sleep(1) if EM.reactor_running? # allow some time for the user get written and sync'd
        u = User.first( :conditions => { 'authentications.provider' => provider, 'authentications.uid' => uid } )
        return u if u
        
        Rails.logger.error "[GT::UserManager#get_or_create_faux_user] rescuing Mongo::OperationFailure #{e} / ODD: could not find user from #{provider} with id #{uid}"
        return nil
      end
    end
    
    # Handles faux User becoming *real* User
    def self.convert_faux_user_to_real(user, omniauth)
      # create new auth and drop old auth
      user.authentications = []
      
      new_auth = GT::AuthenticationBuilder.build_from_omniauth(omniauth)
      
      GT::AuthenticationBuilder.normalize_user_info(user, new_auth)
      ensure_valid_unique_nickname!(user)
      user.downcase_nickname = user.nickname.downcase

      user.authentications << new_auth

      user.faux = User::FAUX_STATUS[:converted]
      if user.save
        GT::PredatorManager.initialize_video_processing(user, new_auth)
        StatsManager::StatsD.increment(Settings::StatsConstants.user['new']['converted'], user.id, 'signup')
        return user, new_auth
      else
        StatsManager::StatsD.increment(Settings::StatsConstants.user['new']['error'])        
        Rails.logger.error "[GT::UserManager#convert_faux_user_to_real] Failed to save user: #{user.errors.full_messages.join(',')}"
        return user.errors
      end
    end
    
    # Make sure a user has public, watch_later, upvoted, and viewed _rolls
    # should follow just the public roll
    def self.ensure_users_special_rolls(u, save=false)
      build_public_roll_for_user(u) unless u.public_roll
      u.public_roll.add_follower(u) unless u.following_roll?(u.public_roll)
      u.public_roll.save if save
      
      build_watch_later_roll_for_user(u) unless u.watch_later_roll
      #users don't follow their watch_later_roll
      u.watch_later_roll.save if save
      
      build_upvoted_roll_for_user(u) unless u.upvoted_roll
      #users don't follow their upvoted_roll
      u.upvoted_roll.save if save
      
      build_viewed_roll_for_user(u) unless u.viewed_roll
      #users don't follow their viewed_roll
      u.viewed_roll.save if save
      
      if save and !u.save
        Rails.logger.error "[GT::UserManager#ensure_users_speical_rolls] Failed to save user: #{u.errors.full_messages.join(',')}"
      end
    end
    
    private
      
      # Takes an omniauth hash to build one user, prefs, and an auth to go along with it
      def self.build_new_user_and_auth(omniauth)
        u = User.new

        u.nickname = omniauth['info']['nickname']
        u.nickname = omniauth['info']['name'] if u.nickname.blank? or u.nickname.match(/\.php\?/)

        u.name = omniauth['info']['name']
        
        u.server_created_on = "GT::UserManager#build_new_user_and_auth/#{u.nickname}"

        auth = GT::AuthenticationBuilder.build_from_omniauth(omniauth)

        GT::AuthenticationBuilder.normalize_user_info(u, auth)
        ensure_valid_unique_nickname!(u)
        u.downcase_nickname = u.nickname.downcase

        u.authentications << auth

        u.preferences = Preferences.new()
        u.app_progress = AppProgress.new()
        
        return u, auth
      end
      
      # If we have an FB authentication, poll on demand... and get updated permissions
      def self.update_token_and_permissions(u)
        u.authentications.each do |a| 
          
          GT::PredatorManager.update_video_processing(u, a)
          
          if a.provider == "facebook"
            begin
              graph = Koala::Facebook::GraphAPI.new(a.oauth_token)
              fb_permissions = graph.get_connections("me","permissions")
              a['permissions'] = fb_permissions if fb_permissions
              u.save(:validate => false)
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
        #replace standard junk with underscore
        user.nickname = user.nickname.gsub(/[ ,:&~]/,'_');
        #remove anything not in the set of valid characters
        user.nickname = user.nickname.gsub(User::NICKNAME_UNACCEPTABLE_CHAR_REGEX, '')
        user.nickname = "cobra" if user.nickname.blank?
        
        orig_nick = user.nickname
        i = 2
        
        while( User.where( :downcase_nickname => user.nickname.downcase ).count > 0 ) do
          user.nickname = "#{orig_nick}_#{i}"
          i = i*2
        end
      end
      
      def self.build_public_roll_for_user(u)
        r = Roll.new
        r.creator = u
        r.public = true
        r.collaborative = false
        r.title = u.nickname
        r.thumbnail_url = u.user_image || u.user_image_original
        u.public_roll = r
      end
      
      def self.build_watch_later_roll_for_user(u)
        r = Roll.new
        r.creator = u
        r.public = false
        r.collaborative = false
        r.title = "Watch Later"
        u.watch_later_roll = r
      end
      
      def self.build_upvoted_roll_for_user(u)
        r = Roll.new
        r.creator = u
        r.public = false
        r.collaborative = false
        r.title = "Upvoted"
        u.upvoted_roll = r
      end
      
      def self.build_viewed_roll_for_user(u)
        r = Roll.new
        r.creator = u
        r.public = false
        r.collaborative = false
        r.title = "Viewed"
        u.viewed_roll = r
      end
      
      def self.ensure_app_progress_created(u)
        return if u.app_progress
        u.app_progress = AppProgress.new
        u.save
      end
  end
end