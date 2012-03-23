# encoding: utf-8

# We are using the User model form Shelby (before rolls)
# New vs. old keys will be clearly listed
class User
  include MongoMapper::Document
  safe
    
  include Plugins::MongoMapperConfigurator
  configure_mongomapper Settings::User

  devise  :rememberable, :trackable, :remember_for => 1.week
  #devise includes root in json which fucked up backbone models, need to undo that...
  def self.include_root_in_json() nil; end

  #--new keys--
  
  # the Rolls this user is following and when they started following
  many :roll_followings
  
  # Rolls this user has unfollowed
  # these rolls should not be auto-followed by our system
  key :rolls_unfollowed, Array, :typecase => ObjectId, :abbr => :aa
  
  # A special roll for a user: their public roll
  belongs_to :public_roll, :class_name => 'Roll'
  key :public_roll_id, ObjectId, :abbr => :ab
  
  # A special roll for a user: their Watch Later roll
  belongs_to :watch_later_roll, :class_name => 'Roll'
  key :watch_later_roll_id, ObjectId, :abbr => :ad
  
  # When we create a User just for their public Roll, we mark them faux=true
  #  this status allows us to track conversions from faux to real
  FAUX_STATUS = {
    :false => 0,
    :true => 1,
    :converted => 2
  }.freeze
  key :faux, Integer, :abbr => :ac, :default => FAUX_STATUS[:false]
  
  has_many :dashboard_entries, :foreign_key => :a

  #--old keys--
  many :authentications
  
  one :preferences
  
  key :name,                  String
  #Mongo string matches are case sensitive and regex queries w/ case insensitivity won't actually use index
  #So we downcase the nickname into User and then query based on that (which is now indexed)
  key :nickname,              String, :required => true
  key :downcase_nickname,     String
  key :user_image,            String
  key :user_image_original,   String
  key :primary_email,         String
  
  # so we know where a user was created...
  key :server_created_on,     String, :default => "gt"
  # Used to track referrals (where they are coming from)
  key :referral_frame_id, ObjectId
  
  ## For Devise
  # Rememberable
  key :remember_me,           Boolean, :default => true
  key :remember_created_at,   Time
  key :remember_token,        String
  ## Trackable
  key :sign_in_count,         Integer, :default => 0
  key :current_sign_in_at,    Time
  key :last_sign_in_at,       Time
  key :current_sign_in_ip,    String
  key :last_sign_in_ip,       String
  
  # To keep track of social actions performed by user
  # [twitter, facebook, email, tumblr]
  key :social_tracker,        Array, :default => [0, 0, 0, 0]

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
  
  #if email has changed/been set, update sailthru  &&
  # Be resilient if errors fuck up the create process
  after_save :check_to_send_email_address_to_sailthru
  
  # -- New Methods --
  
  def created_at() self.id.generation_time; end
  
  def following_roll?(r)
    raise ArgumentError, "must supply roll or roll_id" unless r
    roll_id = (r.is_a?(Roll) ? r.id : r)
    roll_followings.any? { |rf| rf.roll_id == roll_id }
  end
  
  def unfollowed_roll?(r)
    raise ArgumentError, "must supply roll or roll_id" unless r
    roll_id = (r.is_a?(Roll) ? r.id : r)
    rolls_unfollowed.include? roll_id
  end
  
  # -- Old Methods --   
  def self.find_by_nickname(n)
    return nil unless n.is_a? String and !n.blank?
    User.first(:conditions=>{:downcase_nickname => n.downcase}) || User.first(:conditions=>{:nickname => /^#{n.downcase}$/i})
  end

  def self.find_by_email(n)
    return nil unless n.is_a? String and !n.blank?
    User.where( :primary_email => /^#{n.downcase}$/i ).first
  end
  
  def self.find_by_provider_name_and_id(name,id)
    return nil unless name.is_a? String and !name.blank?
    return nil unless id.is_a? String and !id.blank?
    User.where('authentications.provider'=> name, 'authentications.uid'=> id).first
  end
  
  def has_primary_email?() self.primary_email && self.primary_email.length > 0; end
  
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
      
  #TODO: Update how we track social actions
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
  
  #TODO: re-implement welcome email  
  def send_email_address_to_sailthru(list=Settings::Sailthru.user_list)
    EM.next_tick do
      #client = Bacon::Email.new()
      #client.add_email_address(self.primary_email, list)
    end
  end
  
  private
        
    def check_to_send_email_address_to_sailthru
      send_email_address_to_sailthru() if self.primary_email_changed? and self.primary_email and Rails.env == "production"
    end
    
end
