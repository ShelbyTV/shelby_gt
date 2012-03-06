require 'beanstalk-client'

class Authentication
  include MongoMapper::EmbeddedDocument
  plugin MongoMapper::Plugins::Timestamps
  
  timestamps!
    
  embedded_in :user 
  
  key :provider,  String
  key :uid,       String
  key :oauth_token,   String
  key :oauth_secret,  String
  
  #oauth user info
  key :name,        String
  key :nickname,    String
  key :email,       String
  key :first_name,  String
  key :last_name,   String
  key :location,    String
  key :description, String
  key :image,       String
  key :phone,       String
  key :urls,        String
  key :user_hash,   String
  key :gender,      String
  key :timezone,    String
  key :permissions, Array

  #Errors
  key :init_error,  Boolean, :default => false
  
  validate :ensure_valid_for_provider

  #It seems that (:on => :create) is ignored when using MongoMapper
  before_save(:on => :create) { self.initialize_video_processing if self.new? }
    
  def self.build_from_omniauth(omniauth)
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
  
  def twitter?() provider == "twitter"; end

  def facebook?() provider == "facebook"; end
  def tumblr?() provider == "tumblr"; end
  
  def update_oauth_tokens!(omniauth)
    if oauth_token != omniauth['credentials']['token'] or oauth_secret != omniauth['credentials']['secret']
      update_attributes!({ :oauth_token => omniauth['credentials']['token'], :oauth_secret => omniauth['credentials']['secret'] })
      
      #and need the node processes to update as well
      update_video_processing
      
      # TODO: FIXME
      #Stats.increment(Stats::UPDATED_OAUTH_TOKENS)
    end
    return self
  end
  
  # gets as many videos from statuses available and adds user to site streaming
  def initialize_video_processing
    return unless Settings::Beanstalk.beanstalk_available

    begin
      beanstalk = Beanstalk::Connection.new(Settings::Beanstalk.beanstalk_ip)
      case self.provider
      when 'twitter'
        tw_add_backfill(beanstalk)
        tw_add_to_stream(beanstalk)
        # TODO: FIXME
        #Stats.increment(Stats::USER_ADD_TWITTER, user.id, 'add_twitter')
      when 'facebook'
        fb_add_user(beanstalk)
        # TODO: FIXME
        #Stats.increment(Stats::USER_ADD_FACEBOOK, user.id, 'add_facebook')
      when 'tumblr'
        tumblr_add_user(beanstalk)
        # TODO: FIXME
        #Stats.increment(Stats::USER_ADD_TUMBLR, user.id, 'add_tumblr')
      end
    rescue => e
      Rails.logger.error("Error: Video processing initialization failed for user #{user.id}: #{e}")
    end
  end
  
  def update_video_processing
    return unless Settings::Beanstalk.beanstalk_available

    begin
      beanstalk = Beanstalk::Connection.new(Settings::Beanstalk.beanstalk_ip)
      case self.provider
      when 'twitter'
        #unneccssary as twitter doesn't need tokens for site streaming
      when 'facebook'
        #add_user job also updates user
        fb_add_user(beanstalk)
      when 'tumblr'
        #do we need this?
      end
    rescue => e
      Rails.logger.error("Error: Video processing update failed for user #{user.id}: #{e}")
    end
  end
  
  private
    
    def tumblr_add_user(bean)
      bean.use(Settings::Beanstalk.tumblr_add_user)      # insures we are using watching tumblr_backfill tube
      add_user_job = {:tumblr_id => self.uid, :oauth_token => self.oauth_token, :oauth_secret => self.oauth_secret}
      bean.put(add_user_job.to_json)
    end
    
    def fb_add_user(bean)
      bean.use(Settings::Beanstalk.facebook_add_user)      # insures we are using watching fb_add_user tube
      add_user_job = {:fb_id => self.uid, :fb_access_token => self.oauth_token}
      bean.put(add_user_job.to_json)
    end

    def tw_add_backfill(bean)
      bean.use(Settings::Beanstalk.twitter_backfill)      # insures we are using watching tw_backfill tube
      backfill_job = {:action=>'add_user', :twitter_id => self.uid, :oauth_token => self.oauth_token, :oauth_secret => self.oauth_secret}
      bean.put(backfill_job.to_json)
    end

    def tw_add_to_stream(bean)
      bean.use(Settings::Beanstalk.twitter_add_stream)    # insures we are using tw_stream_add tube
      stream_job = {:action=>'add_user', :twitter_id => self.uid}
      bean.put(stream_job.to_json)
    end
    
    def ensure_valid_for_provider
      if 'twitter' == provider
        errors.add(:provider, "is mising some info.  nickname:#{nickname}, name:#{name}, provider:#{provider}, uid:#{uid}, oauth_token:#{oauth_token}, oauth_secret:#{oauth_secret}") if
          (nickname.blank? and name.blank?) or provider.blank? or uid.blank? or oauth_token.blank? or oauth_secret.blank?
      elsif 'facebook' == provider
        errors.add(:provider, "is mising some info.  nickname:#{nickname}, name:#{name}, provider:#{provider}, uid:#{uid}, oauth_token:#{oauth_token}") if
          (nickname.blank? and name.blank?) or provider.blank? or uid.blank? or oauth_token.blank?
      elsif 'tumblr' == provider
        errors.add(:provider, "is mising some info.  nickname:#{nickname}, name:#{name}, provider:#{provider}, uid:#{uid}, oauth_token:#{oauth_token}, oauth_secret:#{oauth_secret}") if
          (nickname.blank? and name.blank?) or provider.blank? or uid.blank? or oauth_token.blank? or oauth_secret.blank?
      else
        errors.add(:provider, "we don't support this provider yet")
      end
    end
  
end