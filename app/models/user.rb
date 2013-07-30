# encoding: utf-8
require 'user_manager'
require 'securerandom'
require 'rhombus'
require 'api_clients/sailthru_client'

# We are using the User model form Shelby (before rolls)
# New vs. old keys will be clearly listed
class User
  include MongoMapper::Document
  safe

  include Plugins::MongoMapperConfigurator
  configure_mongomapper Settings::User

  include Paperclip::Glue

  before_validation(:on => :update) { self.ensure_valid_unique_nickname }
  before_save :update_public_roll_title

  devise  :rememberable, :trackable, :token_authenticatable, :database_authenticatable, :recoverable, :remember_for => 12.weeks
  #devise includes root in json which fucked up backbone models, need to undo that...
  def self.include_root_in_json() nil; end

  #--new keys--

  # the Rolls this user is following and when they started following
  many :roll_followings

  # We may embed lots of roll_followings which results in a stack level too deep issue (b/c of the way MM/Rails does validation chaining)
  # But since we don't use validations or callbacks, we can hack around this issue:
  embedded_callbacks_off

  # Rolls this user has unfollowed
  # these rolls should not be auto-followed by our system
  key :rolls_unfollowed, Array, :typecast => 'ObjectId', :abbr => :aa, :default => []

  # A special roll for a user: their public roll
  belongs_to :public_roll, :class_name => 'Roll'
  key :public_roll_id, ObjectId, :abbr => :ab

  # A special roll for a user: their Watch Later Roll
  # - contains trivial copies of Frames that this user has marked to Watch Later
  belongs_to :watch_later_roll, :class_name => 'Roll'
  key :watch_later_roll_id, ObjectId, :abbr => :ad

  # A special roll for a user: their Upvoted Roll
  # - contains trivial copies of Frames that this user has upvoted
  # - from the consumer side of the api its known as the "heart_roll"
  belongs_to :upvoted_roll, :class_name => 'Roll'
  key :upvoted_roll_id, ObjectId, :abbr => :ae

  # A special roll for a user: their Viewed Roll
  # - contains trivial copies of Frames that this user has viewed
  belongs_to :viewed_roll, :class_name => 'Roll'
  key :viewed_roll_id, ObjectId, :abbr => :af

  # When we create a User just for their public Roll, we mark them user_type=faux
  #  this status allows us to track conversions from faux to real
  # Users created only for the purpose of processing services like bot rolls
  #  or feed processing should be assigned user_type=service
  USER_TYPE = {
    :real => 0,
    :faux => 1,
    :converted => 2,
    :service => 3
  }.freeze
  key :user_type, Integer, :abbr => :ac, :default => USER_TYPE[:real]

  has_many :dashboard_entries, :foreign_key => :a

  #for mobile token authentication
  key :authentication_token, String, :abbr => :ah

  # has this user been granted access to Shelby GT?
  key :gt_enabled, Boolean, :abbr => :ag, :default => false

  one :app_progress

  key :applications, Array, :abbr => :ap
  key :clients, Array, :abbr => :ai

  key :cohorts, Array, :typecast => 'String', :abbr => :aq, :default => []

  key :autocomplete, Hash, :abbr => :as

  #--old keys--
  # NB: embedded callbacks are disabled on User
  many :authentications

  one :preferences

  key :name,                  String
  #Mongo string matches are case sensitive and regex queries w/ case insensitivity won't actually use index
  #So we downcase the nickname into User and then query based on that (which is now indexed)
  key :nickname,              String, :required => true
  key :downcase_nickname,     String
  key :user_image,            String  # actual URL provided by service
  key :user_image_original,   String  # guess of URL to original upload that became user_image
  key :primary_email,         String, :default => nil
  key :encrypted_password,    String, :abbr => :ar

  # uploadable avatar via paperclip (see config/initializers/paperclip.rb for defaults)
  # To simplify things, a user's Shelby avatar S3 file name is deterministic based on the user's id.
  #
  # Using the format of :path below, here's how you construct an avatar URL:
  #   http://s3.amazonaws.com/shelby-gt-user-avatars/<style>/<user.id>
  # Where <style> is one of the pre-defined sizes is user.rb, currently:
  # :styles => { :sq192x192 => "192x192#", :sq48x48 => "48x48#" }
  #
  # Example of a large thumbnail URL:
  #   http://s3.amazonaws.com/dev-shelby-gt-user-avatars/sq192x192/4fa141009fb5ba2b2b000002
  #
  # You can also get at the originally uploaded image (with original aspect ratio) using the "original" style:
  #   http://s3.amazonaws.com/dev-shelby-gt-user-avatars/original/4fa141009fb5ba2b2b000002
  #
  has_attached_file :avatar,
    :styles => { :sq192x192 => "192x192#", :sq48x48 => "48x48#" },
    :bucket => Settings::Paperclip.user_avatar_bucket,
    :path => "/:style/:id"
  key :avatar_file_name,      String, :abbr => :at
  key :avatar_file_size,      String, :abbr => :au
  key :avatar_content_type,   String, :abbr => :av
  key :avatar_updated_at,     String, :abbr => :aw


  # so we know where a user was created...
  key :server_created_on,     String, :default => "gt"
  # Used to track referrals (where they are coming from)
  key :referral_frame_id, ObjectId

  # define admin users who can access special areas
  key :is_admin,              Boolean, :default => false

  # giving some user special abilities (ie ["multi_roll_roller"])
  key :additional_abilities,  Array, :typecast => 'String', :abbr => :ba, :default => []

  ## For Devise
  # Rememberable
  # key :remember_me getting set to false by Devise, which we never want, so...
  def remember_me() return true; end
  def remember_me?() return true; end
  key :remember_created_at,   Time
  key :remember_token,        String
  # Recoverable
  key :reset_password_token,  String, :abbr => :ax
  key :reset_password_sent_at,Time,   :abbr => :ay
  # Trackable
  key :sign_in_count,         Integer, :default => 0
  key :session_count,         Integer, :default => 0
  key :current_sign_in_at,    Time
  key :last_sign_in_at,       Time
  key :current_sign_in_ip,    String
  key :last_sign_in_ip,       String

  # To keep track of social actions performed by user
  # [twitter, facebook, email, tumblr]
  key :social_tracker,        Array, :default => [0, 0, 0, 0]

  key :beta_invites_available,  Integer, :default => 3, :abbr => :az

  # Concept "User Channels" :
  # A publicly accessible channel (presented like any Roll) backed by the DashboardEntries of a User, instead of the Frame's of a Roll.
  # Manually created users follow a few rolls which creates the channel.
  # Make the dashboard publicly accessible with this attribute:
  key :public_dashboard,      Boolean, :default => false, :abbr => :bb

  # a url for a user's external website so we can provide a link to it
  key :website,                String, :abbr => :bc
  # a description for the user's .tv network
  key :dot_tv_description,     String, :abbr => :bd

  #The set of unique Google Analytics mobile client identifiers linking this user to GA
  #Set b/c a given user may log in on multiple devices, or across multiple installs on a single device
  key :google_analytics_client_ids,  Array, :typecast => 'String', :abbr => :be, :default => []

  # a hash of counts of the number of items rolled from different sources by the user
  # since the last time we told them about it
  key :rolled_since_last_notification, Hash, :abbr => :bf, :default => {"email" => 0}

  attr_accessible :name, :nickname, :password, :password_confirmation, :primary_email, :preferences, :app_progress, :user_image, :user_image_original, :avatar,
                  :google_analytics_client_id, :rolled_since_last_notification

  # Arnold does a *shit ton* of user saving, which runs this validation, which turns out to be very expensive
  # (see shelby_gt/etc/performance/unique_nickname_realtime_profile.gif)
  # This validations is technically unnecessary because there is a unique index on user.nickname in the database.
  # Additionally: 1) Arnold performans manual validation on User create. 2) This doesn't even gurantee uniqueness (timing issues)
  # So, we turn this validation off for performance reasons inside of Arnold
  if Settings::Performance.validate_uniqueness_user_nickname
    validates_uniqueness_of :nickname
  end

  if Settings::Performance.validate_uniqueness_primary_email
    before_validation(:on => :create) { self.drop_primary_email_if_taken }
    validates_uniqueness_of :primary_email, :allow_blank => false, :allow_nil => true
  end

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
  NICKNAME_ACCEPTABLE_REGEX = /\A[a-zA-Z0-9_\.\-\u4e00-\u9fcf\u0400-\u04ff\u00c0-\u02ae\uac00-\ud7af\u1e00-\u1eff\u0e00-\u0e7f\u0600-\u06ff\u0370-\u03ff\u0b80-\u0bff\u0590-\u05ff\u10a0-\u10ff\u3040-\u30ff]+\Z/
  NICKNAME_UNACCEPTABLE_CHAR_REGEX = /[^a-zA-Z0-9_\.\-\u4e00-\u9fcf\u0400-\u04ff\u00c0-\u02ae\uac00-\ud7af\u1e00-\u1eff\u0e00-\u0e7f\u0600-\u06ff\u0370-\u03ff\u0b80-\u0bff\u0590-\u05ff\u10a0-\u10ff\u3040-\u30ff]/
  validates_format_of :nickname, :with => NICKNAME_ACCEPTABLE_REGEX


  RESERVED_NICNAMES = %w(admin system anonymous)
  ROUTE_PREFIXES = %w(signout login users user authentication authentications auth setup bookmarklet pages images javascripts robots stylesheets staging favicon send-invite isolated-roll roll rollFromFrame embed channels help legal search following onboarding preferences likes saves stream tools community)
  validates_exclusion_of :nickname, :in => RESERVED_NICNAMES + ROUTE_PREFIXES

  validates_format_of :primary_email, :with => /\A[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]+\Z/, :allow_blank => true

  validates_attachment_content_type :avatar, :content_type => /image/

  #if email has changed/been set, update sailthru  &&
  # Be resilient if errors fuck up the create process
  after_update :check_to_send_email_address_to_sailthru

  # -- Quasi Keys --

  # devise expects to be able to get email via user.email (not configurable)
  alias_method :email, :primary_email

  # -- New Methods --

  def created_at() self.id.generation_time; end

  # When true, you should display this user's avatar via a deterministic S3 file location (see initializers/paperclip.rb)
  def has_shelby_avatar() !self.avatar_file_name.blank?; end

  def shelby_avatar_url(size)
    avatar_size = case size
                  when "small"
                    "sq48x48"
                  when "large"
                    "sq192x192"
                  when "original"
                    "original"
                  end

    "http://s3.amazonaws.com/#{Settings::Paperclip.user_avatar_bucket}/#{avatar_size}/#{id.to_s}?#{avatar_updated_at}" if has_shelby_avatar
  end

  # When update_attributes recieves a :google_analytics_identifier, add it to our set
  def google_analytics_client_id=(ga_id)
    google_analytics_client_ids_will_change!
    self.google_analytics_client_ids << ga_id unless self.google_analytics_client_ids.include? ga_id
  end

  # only return true if a correct, symmetric following is in the DB (when given a proper Roll and not roll_id)
  # (this works in concert with Roll#add_follower which will fix an asymetric following)
  def following_roll?(r, must_be_symmetric=true)
    raise ArgumentError, "must supply roll or roll_id" unless r
    roll_id = (r.is_a?(Roll) ? r.id : r)
    following = roll_followings.any? { |rf| rf.roll_id == roll_id }
    if r.is_a?(Roll) and must_be_symmetric
      following &= r.following_users.any? { |fu| fu.user_id == self.id }
    end
    return following
  end

  def unfollowed_roll?(r)
    raise ArgumentError, "must supply roll or roll_id" unless r
    roll_id = (r.is_a?(Roll) ? r.id : r)
    rolls_unfollowed.include? roll_id
  end

  def roll_following_for(r)
    raise ArgumentError, "must supply roll or roll_id" unless r
    roll_id = (r.is_a?(Roll) ? r.id : r)
    roll_followings.select { |rf| rf.roll_id == roll_id } [0]
  end

  def permalink() "#{Settings::ShelbyAPI.web_root}/#{self.nickname}"; end

  def revoke(client)
    token = Rack::OAuth2::Server::AccessToken.get_token_for(id.to_s, client, "")
    token.revoke! unless token.nil?
  end


  # Use this to convert User's created on NOS to GT
  # When we move everyone to GT, use the rake task in gt_migration.rb
  def gt_enable!
    unless self.gt_enabled?
      self.gt_enabled = true
      self.user_type = (self.user_type == USER_TYPE[:faux] ? USER_TYPE[:converted] : USER_TYPE[:real])
      self.cohorts << Settings::User.current_cohort unless self.cohorts.include? Settings::User.current_cohort
      GT::UserManager.ensure_users_special_rolls(self, true)
      self.public_roll.roll_type = Roll::TYPES[:special_public_real_user]

      self.save(:validate => false)
      self.public_roll.save(:validate => false)

      ShelbyGT_EM.next_tick {
        rhombus = Rhombus.new('shelby', '_rhombus_gt')
        rhombus.post('/sadd', {:args => ['new_gt_enabled_users', self.id.to_s]})
      }
    end
  end

  def update_for_signup_client_identifier!(client_identifier)
    #prevent web onboarding
    self.app_progress.onboarding = client_identifier
    #add cohort so we can track/find them later
    self.cohorts << client_identifier unless self.cohorts.include? client_identifier

    self.save
  end

  # given a comma separated string or array of strings of autocomplete items in info, store all unique, valid ones
  # in the array at self.autocomplete[key]
  def store_autocomplete_info(key, info)
    if info.respond_to?('map')
      items = info.map{|item| item.to_s.strip}.uniq
    else
      items = info.split(',').map{|item| item.strip}.uniq
    end
    if key == :email
      items.select! {|address| address =~ /\b[A-Z0-9._%a-z\-]+@(?:[A-Z0-9a-z\-]+\.)+[A-Za-z]{2,4}\z/}
    end
    if !items.empty?
      User.collection.update({:_id => self.id}, {:$addToSet => {"as.#{key}" => {:$each => items}}})
      self.reload
    end
  end

  def has_password?
    !self.encrypted_password.blank? and self.encrypted_password.length > 10
  end

  #default implementations hit the DB, and that sucks b/c we don't index on these attributes
  def self.remember_token() SecureRandom.uuid; end
  def self.reset_password_token() SecureRandom.uuid; end

  # -- Old Methods --
  def self.find_by_nickname(n)
    return nil unless n.respond_to? :downcase
    User.first(:conditions=>{:downcase_nickname => n.downcase})
  end

  def self.find_by_provider_name_and_id(name,id)
    return nil unless name.is_a? String and !name.blank?
    return nil unless id.is_a? String and !id.blank?
    User.where('authentications.provider'=> name, 'authentications.uid'=> id).first
  end

  def authentication_by_provider_and_uid(provider, uid)
    authentications.select { |a| a.provider == provider and a.uid == uid } .first
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

  def send_email_address_to_sailthru(list=Settings::Sailthru.user_list)
    ShelbyGT_EM.next_tick do
      APIClients::SailthruClient.add_or_update_user_to_list(self, list)
    end
  end

  def update_public_roll_title
    if changed.include?('nickname') and self.public_roll
      self.public_roll.title = self.nickname
      self.public_roll.save
    end
  end

  def ensure_valid_unique_nickname
    GT::UserManager.ensure_valid_unique_nickname!(self) if self.nickname_changed?
  end

  def drop_primary_email_if_taken
    # Only drop email when new user has authentication
    if self.primary_email and !self.authentications.blank?
      self.primary_email = nil if User.where( :_id.ne => self.id, :primary_email => self.primary_email ).exists?
    end
  end

  # Changes this user's nickname to something fairly random and saves them.
  # (to allow real user to claim this nickname)
  def release_nickname!
    self.nickname = "shelby_#{self.nickname}"
    self.save
  end

  # Returns who invited this user, if anyone
  def invited_by
    invite = BetaInvite.where(:invitee_id => self.id).first
    invite ? invite.sender : nil
  end

  private

    def check_to_send_email_address_to_sailthru
      send_email_address_to_sailthru() if self.primary_email and self.primary_email_changed?
    end

end
