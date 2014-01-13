# encoding: UTF-8

require 'user_action_manager'

class Roll
  include MongoMapper::Document

  include Plugins::MongoMapperConfigurator
  configure_mongomapper Settings::Roll

  include Paperclip::Glue

  # A Roll has many Frames, first and foremost
  many :frames, :foreign_key => :a

  # it was created by somebody
  belongs_to :creator,  :class_name => 'User', :required => true
  key :creator_id,      ObjectId, :abbr => :a

  # it has some basic categorical info
  key :title,           String, :required => true, :abbr => :b
  key :creator_thumbnail_url,   String, :abbr => :c

  # public rolls can be viewed, posted to, and invited to by any user (doesn't have to be following)
  # private rolls can only be viewed, posted to, and invited to by private_collaborators
  key :public,          Boolean,  :default => true,    :abbr => :d

  # collaborative rolls can be posted to by users other than creator, further spcified by public? (above)
  # non-collaborative rolls can only be posted to by creator
  key :collaborative,   Boolean,  :default => true,    :abbr => :e

  # faux-users get public Rolls, we denormalize the network into the roll
  key :origin_network,  String, :abbr => :f
  SHELBY_USER_PUBLIC_ROLL = "shelby_person"

  # The shortlinks created for each type of share, eg twitter, tumblr, email, facebook
  key :short_links, Hash, :abbr => :g, :default => {}

  # boolean indicating whether this roll is a genius roll
  key :genius,          Boolean, :abbr => :h, :default => false

  # indicates the special heart roll (formerly upvoted_roll, known as user.upvoted_roll)
  key :upvoted_roll,    Boolean, :abbr => :i, :default => false

  # running count of frames in the roll, so it doesn't require a query
  key :frame_count,     Integer, :abbr => :j, :default => 0

  # indicates the shelby.tv subdomain where this roll can be accessed as an isolated roll
  key :subdomain,       String, :abbr => :k
  # indicates whether the subdomain for this roll is activated
  key :subdomain_active,Boolean, :abbr => :l, :default => false
  # roll is accesible at the subdomain address if :subdomain is not nil AND :subdomain_active

  key :first_frame_thumbnail_url, String, :abbr => :m

  TYPES = {
    # special rolls that have not yet been updated to their specific type default to :special_roll
    :special_roll => 10,
    :special_public => 11, # <-- faux or anonymous user
    :special_upvoted => 12,
    :special_watch_later => 13,
    :special_viewed => 14,

    # Differentiate special_public rolls of real shelby users and faux users we deem important
    :special_public_real_user => 15, # <-- actual user
    :special_public_upgraded => 16,  # <-- faux user who we deem worthy

    # User-created non-collaborative public rolls (previously these were collaborative, we're changing that)
    :user_public => 30,
    # Company-created collaborative public rolls
    :global_public => 31,
    # User-created collaborative private rolls
    :user_private => 50,
    # User-created private conversations (aka Discussion Rolls)
    :user_discussion_roll => 51,

    :hashtag => 69,

    :genius => 70
  }
  key :roll_type,       Integer, :abbr => :n, :default => TYPES[:special_roll]

  # each user following this roll and when they started following
  # for private collaborative rolls, these are the participating users
  many :following_users

  # We may embed lots of following_users which results in a stack level too deep issue (b/c of the way MM/Rails does validation chaining)
  # But since we don't use validations or callbacks, we can hack around this issue:
  embedded_callbacks_off

  # uploadable header image via paperclip (see config/initializers/paperclip.rb for defaults)
  has_attached_file :header_image,
    :styles => { :guide_wide => "370x50#", :large_wide => "1110x150#" }, # temporary sizes while we test & iterate
    :bucket => Settings::Paperclip.roll_images_bucket,
    :path => "/header/:id/:style/:basename.:extension"
  key :header_image_file_name,      String, :abbr => :o
  key :header_image_file_size,      String, :abbr => :p
  key :header_image_content_type,   String, :abbr => :q
  key :header_image_updated_at,     String, :abbr => :r

  # Track participants involved in Discussion Rolls
  # Array elements are user's BSON ids (as strings) or email address of non-user
  # ex: ["509bc4cd929d2446ea000001", "spinosa@gmail.com", "4fa39bd89a725b1f920008f3"]
  # Field IS indexed (see DiscussionRollController#idnex for example),
  # but roll can also be found by id or via user.roll_followings
  key :discussion_roll_participants,  Array, :typecast => 'String', :abbr => :s

  # Denormalize a bit of frequently used information (added for discussion rolls)
  key :content_updated_at, Time, :abbr => :t

  attr_accessible :title, :creator_thumbnail_url, :header_image

  RESERVED_SUBDOMAINS = %w(gt anal admin qa vanity staging)
  validates_exclusion_of :subdomain, :in => RESERVED_SUBDOMAINS

  def save(options={})
    # if this roll has subdomain access we have to check if we violate the unique index constraint on subdomains
    if has_subdomain_access?
      self.subdomain = title.strip.gsub(/[_\-\s]+/, '-').gsub(/[^A-Za-z\d-]|\A[-]+|[-]+\z/, '').downcase
      self.subdomain_active = true
      begin
        super({:safe => true}.merge!(options))
      rescue Mongo::OperationFailure => e
        if e.error_code == 11000 or e.error_code == 11001
          # we violated the unique index constraint on subdomains, so we just won't give this roll a subdomain
          Rails.logger.error "Roll saving error / Mongo::OperationFailure #{e.error_code} / self is #{self}"
          self.subdomain = nil
          self.subdomain_active = false
          super
        else
          Rails.logger.error "Roll saving error, unexpected Mongo::OperationFailure #{e.error_code}, raising..."
          raise
        end
      end
    else
      self.subdomain = nil
      self.subdomain_active = false
      super
    end
  end

  def has_subdomain_access?
    # only "real" personal rolls get subdomain
    self.roll_type == TYPES[:special_public_real_user] or self.roll_type == TYPES[:special_public_upgraded]
  end

  def created_at() self.id.generation_time; end

  # only return true if a correct, symmetric following is in the DB (when given a proper User and not user_id)
  # (this works in concert with add_follower which will fix an asymetric following)
  def followed_by?(u, must_be_symmetric=true)
    raise ArgumentError, "must supply user or user_id" unless u
    user_id = (u.is_a?(User) ? u.id : u)
    followed = following_users.any? { |fu| fu.user_id == user_id }
    if u.is_a?(User) and must_be_symmetric
      followed &= u.roll_followings.any? { |rf| rf.roll_id == self.id }
    end
    return followed
  end

  def following_users_ids() following_users.map { |fu| fu.user_id }; end

  def following_users_models() following_users.map { |fu| fu.user }; end

  # Will create a symmetric following or make a broken, asymetric following correct.
  def add_follower(u, send_notification=true)
    raise ArgumentError, "must supply user" unless u and u.is_a?(User)

    send_notification = false if ['cg', 'bobhund', 'ugo', 'henry.sztul'].include?(u.nickname)

    return false if self.followed_by?(u)
    return false if self.roll_type == TYPES[:special_watch_later] and self.creator_id != u.id

    self.push_uniq :following_users => FollowingUser.new(:user => u).to_mongo
    u.push_uniq :roll_followings => RollFollowing.new(:roll => self).to_mongo

    #need to reload so the local copy is up to date for future operations
    self.reload
    u.reload

    if send_notification
      # create dbe for iOS Push and Notification Center notifications, asynchronously
      GT::NotificationManager.check_and_send_join_roll_notification(u, self, [:notification_center])
      # send email notification in a non-blocking manor
      ShelbyGT_EM.next_tick { GT::NotificationManager.check_and_send_join_roll_notification(u, self) }
    end

    GT::UserActionManager.follow_roll!(u.id, self.id)
  end

  # Param explicit=true should be used when a user explicity takes the action to unfollow the roll
  def remove_follower(u, explicit=true)
    raise ArgumentError, "must supply user" unless u and u.is_a?(User)

    return false unless self.followed_by?(u, false) #doesntt have to be symmetric for remove to proceed

    self.following_users.delete_if { |fu| fu.user_id == u.id }
    u.roll_followings.delete_if { |rf| rf.roll_id == self.id }

    if explicit
      u.rolls_unfollowed << self.id
      GT::UserActionManager.unfollow_roll!(u.id, self.id) if u.save and self.save
    end

    return true
  end

  # For all followers, remove their roll following, but do not save this as a UserAction since it isn't
  # Sets this roll's following_users to an empty array when complete
  #
  # N.B. When a user unfollows a roll, should use remove_follower as that tracks the action properly
  def remove_all_followers!
    # not using remove_follower on each one of these users b/c it's not an action taken by an individual
    self.following_users.each do |fu|
      if fu.user
        fu.user.roll_followings.delete_if { |rf| rf.roll_id == self.id }
        fu.user.save
      end
    end
    self.following_users = []
    self.save
    true
  end

  # Anybody can view a public roll
  # Creator of a roll can always view it
  # Private rolls are only viewable by followers
  def viewable_by?(u)
    return true if self.public?
    return false unless u
    user_id = (u.is_a?(User) ? u.id : u)

    return true if self.creator_id == user_id

    #private roll user didn't create, must be a follower to view
    return self.following_users.any? { |fu| fu.user_id == user_id }
  end

  # Only creator can post to a non-collaborative roll
  # Anybody can post to public collaborative roll
  # Only followers can post to private, collaborative roll
  def postable_by?(u)
    return true if self.public? and self.collaborative?
    return false unless u

    # Admins may post to any roll
    return true if u.is_a?(User) and u.is_admin?

    user_id = (u.is_a?(User) ? u.id : u)

    return true if self.creator_id == user_id

    return false unless self.collaborative?

    return true if self.public?

    # private collaborative roll, must be a follower to post
    return self.following_users.any? { |fu| fu.user_id == user_id }
  end

  # The creator of a roll can not leave a roll.
  # To leave a roll a user must delete it.
  def leavable_by?(u)
    raise ArgumentError, "must supply user or user_id" unless u
    user_id = (u.is_a?(User) ? u.id : u)

    return self.creator_id != user_id
  end

  # if you can view it, you can invite to it
  def invitable_to_by?(u) viewable_by?(u); end

  def destroyable_by?(u)
    return true if self.creator == nil
    if self.creator == u
      return (self.creator.public_roll != self and
        self.creator.watch_later_roll != self and
        self.creator.upvoted_roll != self and
        self.creator.viewed_roll != self)
    end
    return false
  end

  def permalink()
    if [ Roll::TYPES[:special_public_real_user],
         Roll::TYPES[:special_public_upgraded],
         Roll::TYPES[:user_public],
         Roll::TYPES[:global_public]
       ].include? self.roll_type
      "#{Settings::ShelbyAPI.web_root}/#{self.creator.nickname}/shares"
    else
      "#{Settings::ShelbyAPI.web_root}/roll/#{self.id}"
    end
  end

  def subdomain_permalink()
    "http://#{subdomain}.#{Settings::ShelbyAPI.web_domain}" if subdomain = self.subdomain
  end


  def display_thumbnail_url() self.upvoted_roll? ? "#{Settings::ShelbyAPI.web_root}/images/assets/favorite_roll_avatar.png" : self.creator_thumbnail_url; end

end
