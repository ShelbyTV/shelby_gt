# encoding: utf-8

# We are using the User model form Shelby (before rolls)
# New vs. old keys will be clearly listed
class User
  include MongoMapper::Document
    
  include Plugins::MongoMapperConfigurator
  configure_mongomapper Settings::User

  devise  :rememberable, :trackable
  #devise includes root in json which fucked up backbone models, need to undo that...
  def self.include_root_in_json() nil; end

  #--new keys--
  
  # the Rolls this user is following and when they started following
  many :roll_followings
  
  # Rolls this user has unfollowed
  # these rolls should not be auto-followed by our system
  key :rolls_unfollowed, Array, :typecase => ObjectId, :abbr => :aa

  #--old keys--
  
  many :authentications do
    def << (a)
      super(a)
      proxy_owner.incorporate_auth_info(a)
    end
  end
  
  one :preferences
  
  key :name,                  String
  #Mongo string matches are case sensitive and regex queries w/ case insensitivity won't actually use index
  #So we downcase the nickname into User and then query based on that (which is now indexed)
  key :nickname,              String, :required => true
  key :downcase_nickname,     String
  key :user_image,            String
  key :user_image_original,   String
  key :primary_email,         String
  
  # Used to track referrals (where they are coming from)
  key :referral_frame_id, ObjectId
  
  
  # for rememberable functionality with devise
  key :remember_me,           Boolean, :default => true

  # To keep track of social actions performed by user
  # [twitter, facebook, email, tumblr]
  key :social_tracker,        Array, :default => [0, 0, 0, 0]
  
  key :server_created_on,     String, :default => "gt"

  #TODO: finish this list
  attr_accessible :name, :nickname, :primary_email
  
  validates_uniqueness_of :nickname, :case_sensitive => false
  
  # Latin-1 and other extensions:   \u00c0 - \u02ae
  # Greek, Coptic:                  \u0370 - \u03ff 
  # Cyrillic:                       \u0400 - \u04ff
  # Hebrew:                         \u0590 - \u05ff
  # Arabic:                         \u0600 - \u06ff
  # Tamil:                          \u0b80 - \u0bff
  # Thai:                           \u0e00 - \u0e7f
  # Georgian:                       \u10a0 - \u10ff
  # Latin extended additional:      \u1e00 - \u1eff
  # Hiragan:                        \u3040 - \u309f -> combined to be \u3040 - \u30ff
  # Katakana:                       \u30a0 - \u30ff /  
  # CJK Unified Ideographs:         \u4e00 - \u9fcf
  # Hangul Syllables:               \uac00 - \ud7af
  validates_format_of :nickname, :with => /\A[a-zA-Z0-9_\.\-\u4e00-\u9fcf\u0400-\u04ff\u00c0-\u02ae\uac00-\ud7af\u1e00-\u1eff\u0e00-\u0e7f\u0600-\u06ff\u0370-\u03ff\u0b80-\u0bff\u0590-\u05ff\u10a0-\u10ff\u3040-\u30ff]+\Z/
  
  RESERVED_NICNAMES = %w(admin system anonymous shelby)
  ROUTE_PREFIXES = %w(signout login users user authentication authentications auth setup bookmarklet pages images javascripts robots stylesheets favicon)
  validates_exclusion_of :nickname, :in => RESERVED_NICNAMES + ROUTE_PREFIXES
  
  validates_format_of :primary_email, :with => /\A[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]+\Z/, :allow_blank => true
  
  # It seems that (:on => :create) is ignored when using MongoMapper
  before_validation(:on => :create) { |u| u.make_unique_nickname if u.new? }
  before_save :set_downcase_nickname
  #if email has changed/been set, update sailthru  &&
  # Be resilient if errors fuck up the create process
  after_save :check_to_send_email_address_to_sailthru
  
  # MongoMapper is fucking up if you pass before_create an array of methods (although array is fine in after_create)
  before_create :set_preferences
  after_create :populate_bootstrap_frame, :send_stats
  
  # -- Methods --
  
  def created_at() self.id.generation_time; end
  
  def make_unique_nickname
    #replace whitespace with underscore
    self.nickname = self.nickname.gsub(' ','_');
    #remove punctuation
    self.nickname = self.nickname.gsub(/['‘’"`]/,'');
    
    while( User.count( :conditions => { :downcase_nickname => self.nickname.downcase } ) > 0 ) do
      self.nickname += NICKNAME_EXTENSIONS[rand(NICKNAME_EXTENSIONS.size)]
    end
  end
  
  def self.find_by_nickname(n)
    return nil unless n.is_a? String and !n.blank?
    User.first( :conditions => { :downcase_nickname => n.downcase } ) || User.first( :conditions => { :nickname => /^#{n.downcase}$/i } )
  end

  def self.find_by_email(n)
    return nil unless n.is_a? String and !n.blank?
    User.first( :conditions => { :primary_email => /^#{n.downcase}$/i } )
  end
  
  def self.find_by_provider_name_and_id(name,id)
    return nil unless name.is_a? String and !name.blank?
    User.first(:conditions=>{'authentications.provider'=> name, 'authentications.uid'=> id})
  end
  def do_at_sign_in
    # if we have an FB authentication, poll on demand...
    self.authentications.each do |a| 
      a.update_video_processing
      if a.provider == "facebook"
        graph = Koala::Facebook::GraphAPI.new(a.oauth_token)
        begin
          fb_permissions = graph.get_connections("me","permissions")
          a['permissions'] = fb_permissions if fb_permissions
          self.save
        rescue Koala::Facebook::APIError => e
          Rails.logger.error "ERROR with getting Facebook Permissions: #{e}"
        end
      end
    end
  end
  
  def has_primary_email?() self.primary_email && self.primary_email.length > 0; end
  
  def following_roll?(r)
    raise ArgumentError, "must supply roll or roll_id" unless r
    roll_id = (r.is_a?(Roll) ? r.id : r)
    roll_followings.any? { |rf| rf.roll_id == roll_id }
  end
  
  ## ====== :: TODO: Update how we track this ====== ##
  #################################################################
  # Social Action Tracking
  #   -updates the hash that tracks how much a user tweets/comments
  ################################################################
  def update_tracker(action)
    case action
    when 'twitter'
      self.social_tracker[0] += 1
    when 'facebook'
      self.social_tracker[1] += 1
    when 'email'
      self.social_tracker[2] += 1
    when 'tumblr'
      if self.social_tracker[3] = nil
        self.social_tracker[3] = 1
      else
        self.social_tracker[3] += 1
      end
    end
    self.save
  end  
  
  def total_tracker_count() self.social_tracker.inject(:+); end
  
  #####################################################
  # Authentications
  ####################################################
  def self.new_from_omniauth(omniauth, referral_broadcast_id=nil)
    nickname = omniauth['user_info']['nickname']
    # If we don't get a nickname, or facebook returns their funky "profile.php?id=676553813": set it to their regular name
    nickname = omniauth['user_info']['name'] if nickname.blank? or nickname.match(/\.php\?/)
    
    begin
      referral_broadcast_id = BSON::ObjectId.from_string(referral_broadcast_id) unless referral_broadcast_id.blank?
    rescue BSON::InvalidObjectId
      referral_broadcast_id = nil
    end
    
    User.new( 
      :name => omniauth['user_info']['name'],
      :nickname => nickname,
      :referral_broadcast_id => referral_broadcast_id
    )
  end
  
  def self.new_from_facebook(oauth_token)
    graph = Koala::Facebook::GraphAPI.new(oauth_token)
    fb_info = graph.get_object('me')
    fb_permissions = graph.get_connections("me","permissions")
    nickname = fb_info["username"]
    # If we don't get a nickname, or facebook returns their funky "profile.php?id=676553813": set it to their regular name
    nickname = fb_info["name"] if nickname.blank? or nickname.match(/\.php\?/)
    
    new_user = User.new( 
      :name => fb_info['name'],
      :nickname => nickname
    )
    new_user.authentications << Authentication.build_from_facebook(fb_info, oauth_token, fb_permissions)
    return new_user
  end
  
  def incorporate_auth_info(authentication)
    self.user_image = authentication.image if !self.user_image and authentication.image

    # If auth is twitter, we can try removing the _normal before the extension of the image to get the large version...
    if !self.user_image_original and authentication.twitter? and !authentication.image.blank? and !authentication.image.include?("default_profile")
      self.user_image_original = authentication.image.gsub("_normal", "")
    end
      
    self.primary_email = authentication.email if self.primary_email.blank? and !authentication.email.blank?
  end
  
  def update_authentication_tokens!(omniauth)
    auth = self.authentication_by_provider_and_uid(omniauth['provider'], omniauth['uid'])
    return auth ? auth.update_oauth_tokens!(omniauth) : false
  end
  
  def authentication_by_provider_and_uid(provider, uid)
    authentications.select { |a| a.provider == provider and a.uid == uid } .first
  end
  
  def has_equivalent_authentication?(a)
    !!authentication_by_provider_and_uid(a.provider, a.uid)
  end
  
  def has_provider?(provider) 
    authentications.any? {|a| provider == a.provider }
  end
  alias_method :has_provider, :has_provider?
  
  # returns the *first* matching provider
  # N.B. If we support multiple accounts from the same provider, you may want to query more specfically!
  def first_provider(provider)
    @first_provider ||= authentications.each { |a| return a if a.provider == provider }
  end
  
  # returns the nickname from the first matching provider
  def nickname_on_first_provider(provider)
    @nickname_on_first_provider ||= first_provider(provider) ? first_provider(provider).nickname : nil
  end

  # returns the uid from the first matching provider
  def uid_on_first_provider(provider)
    @uid_on_first_provider ||= first_provider(provider) ? first_provider(provider).uid : nil
  end
      
  # Update user count stat
  def send_stats
    #Stats.increment(Stats::TOTAL_USERS)
    #TODO: FIXME
    return true
  end
  
  def send_email_address_to_sailthru(list="#{Settings::Global.sailthru_user_list}")
      #client = Bacon::Email.new()
      #client.add_email_address(self.primary_email, list)
      #TODO: FIXME
  end
  handle_asynchronously :send_email_address_to_sailthru
  
  private
    
    def set_preferences
      self.preferences = Preferences.new()
      return true
    end
    
    
    def check_to_send_email_address_to_sailthru
      send_email_address_to_sailthru() if self.primary_email_changed? and self.primary_email
    end
    
    def populate_bootstrap_frame   
      #TODO: First add the frame from referral, if any
      unless self.referral_frame_id.blank?
        referral_frame = Frame.find(self.referral_frame_id)
        if referral_frame
          #reroll = referral_frame.re_roll()
        end
      end
    
      # TODO: Always add our own bootstrap video...
    
      return true
    end
  
    def set_downcase_nickname() self.downcase_nickname = self.nickname.downcase; end  
    
    NICKNAME_EXTENSIONS = ["bagels", "x10", "thegreat", "enfuego", "money"]
end
