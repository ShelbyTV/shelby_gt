# encoding: UTF-8

require 'beanstalk-client'

# This is the one and only place where Users are created.
#
# Used to create actual users (on signup) and faux Users (for public Roll)
#
module GT
  class UserManager
    
    # Creates a real User on signup
    def self.create_new_user_from_omniauth(omniauth)
      u = User.new
      
      u.nickname = omniauth['user_info']['nickname']
      u.nickname = omniauth['user_info']['name'] if u.nickname.blank? or u.nickname.match(/\.php\?/)
      
      u.name = omniauth['user_info']['name']
      
      auth = build_authentication_from_omniauth(omniauth)

      fill_in_user_with_auth_info(u, auth)
      ensure_valid_unique_nickname!(u)
      u.downcase_nickname = u.nickname.downcase
      
      u.authentications << auth
      
      u.preferences = Preferences.new()

      if u.save
        initialize_video_processing(u, auth)
        
        # Update user count stat
        #Stats.increment(Stats::TOTAL_USERS)
        return u
      else
        puts u.errors.full_messages
        return u.errors
      end
    end
    
    # Things that happen when a user signs in.
    def self.start_user_sign_in(user, omniauth=nil, session=nil)
      update_authentication_tokens!(user, omniauth) if omniauth
      update_on_sign_in(user)
      # Always remember users, onus is on them to log out
      user.remember_me!
    end
    
    def self.add_new_auth_from_omniauth(user, omniauth)
      new_auth = build_authentication_from_omniauth(omniauth)
      user.authentications << new_auth
      if user.save
        initialize_video_processing(user, new_auth)        
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
      
      # Takes an omniauth response and bulds a new authentication
      # - returns the new authentication
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
      
      # Takes facebook info and bulds a new authentication
      # - returns the new authentication
      def self.build_authentication_from_facebook(fb_info, token, fb_permissions)
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

      def self.fill_in_user_with_auth_info(u, auth)
        u.user_image = auth.image if !u.user_image and auth.image
        
        #If auth is twitter, we can try removing the _normal before the extension of the image to get the large version...
        if !u.user_image_original and auth.twitter? and !auth.image.blank? and !auth.image.include?("default_profile")
          u.user_image_original = auth.image.gsub("_normal", "")
        end
        u.primary_email = auth.email if u.primary_email.blank? and !auth.email.blank?
      end

      # Finds a users authentication and updates it
      #  - returns the updated auth      
      def self.update_authentication_tokens!(u,omniauth)
        auth = authentication_by_provider_and_uid(u, omniauth['provider'], omniauth['uid'])
        return auth ? update_oauth_tokens!(u, auth, omniauth) : false
      end
      
      # Updates oauth tokens for a users auth given an authentication
      #  - returns the updated auth
      def self.update_oauth_tokens!(u, a, omniauth)
        if a.oauth_token != omniauth['credentials']['token'] or a.oauth_secret != omniauth['credentials']['secret']
          a.update_attributes!({ :oauth_token => omniauth['credentials']['token'], :oauth_secret => omniauth['credentials']['secret'] })

          #and need the node processes to update as well
          update_video_processing(u, a)
        end
        return a
      end
      
      # Finds a auth by provider and id
      def self.authentication_by_provider_and_uid(u, provider, uid)
        u.authentications.select { |a| a.provider == provider and a.uid == uid } .first
      end
      
      # If we have an FB authentication, poll on demand... and get updated permissions
      def self.update_on_sign_in(u)
        u.authentications.each do |a| 
          update_video_processing(u, a)
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
      
      # gets as many videos from statuses available and adds user to site streaming
      def self.initialize_video_processing(u, a)
        return unless Settings::Beanstalk.beanstalk_available

        begin
          bean = Beanstalk::Connection.new(Settings::Beanstalk.beanstalk_ip)
          case a.provider
          when 'twitter'
            tw_add_backfill(a, bean)
            tw_add_to_stream(a, bean)
          when 'facebook'
            fb_add_user(a, bean)
          when 'tumblr'
            tumblr_add_user(a, bean)
          end
        rescue => e
          Rails.logger.error("Error: Video processing initialization failed for user #{u.id}: #{e}")
        end
      end
      
      # Puts jobs on Queues to get most recent video we may have missed
      def self.update_video_processing(u, a)
        return unless Settings::Beanstalk.beanstalk_available

        begin
          beanstalk = Beanstalk::Connection.new(Settings::Beanstalk.beanstalk_ip)
          case a.provider
          when 'twitter'
            #unneccssary as twitter doesn't need tokens for site streaming
          when 'facebook'
            #add_user job also updates user
            fb_add_user(a, beanstalk)
          when 'tumblr'
            #do we need this?
          end
        rescue => e
          Rails.logger.error("Error: Video processing update failed for user #{u.id}: #{e}")
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
      
      ###########################################
      # Adding jobs to Message Queue
      def self.tumblr_add_user(a, bean)
        bean.use(Settings::Beanstalk.tumblr_add_user)      # insures we are using watching tumblr_backfill tube
        add_user_job = {:tumblr_id => a.uid, :oauth_token => a.oauth_token, :oauth_secret => a.oauth_secret}
        bean.put(add_user_job.to_json)
      end
      
      def self.fb_add_user(a, bean)
        bean.use(Settings::Beanstalk.facebook_add_user)      # insures we are using watching fb_add_user tube
        add_user_job = {:fb_id => a.uid, :fb_access_token => a.oauth_token}
        bean.put(add_user_job.to_json)
      end

      def self.tw_add_backfill(a, bean)
        bean.use(Settings::Beanstalk.twitter_backfill)      # insures we are using watching tw_backfill tube
        backfill_job = {:action=>'add_user', :twitter_id => a.uid, :oauth_token => self.oauth_token, :oauth_secret => self.oauth_secret}
        bean.put(backfill_job.to_json)
      end

      def self.tw_add_to_stream(a, bean)
        bean.use(Settings::Beanstalk.twitter_add_stream)    # insures we are using tw_stream_add tube
        stream_job = {:action=>'add_user', :twitter_id => a.uid}
        bean.put(stream_job.to_json)
      end
      
    
  end
end