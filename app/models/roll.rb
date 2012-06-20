# encoding: UTF-8

require 'user_action_manager'

class Roll
  include MongoMapper::Document

  include Plugins::MongoMapperConfigurator
  configure_mongomapper Settings::Roll
  
  # A Roll has many Frames, first and foremost
  many :frames, :foreign_key => :a
  
  # it was created by somebody
  belongs_to :creator,  :class_name => 'User', :required => true
  key :creator_id,      ObjectId, :abbr => :a
  
  # it has some basic categorical info
  key :title,           String, :required => true, :abbr => :b
  key :thumbnail_url,   String, :abbr => :c

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

  # each user following this roll and when they started following
  # for private collaborative rolls, these are the participating users
  many :following_users
  
  attr_accessible :title, :thumbnail_url

  RESERVED_SUBDOMAINS = %w(gt anal admin qa vanity)
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
          self.subdomain = nil
          self.subdomain_active = false
          super
        else
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
    # only user's personal roll gets a subdomain
    public and !collaborative and !genius
  end

  def followed_by?(u)
    raise ArgumentError, "must supply user or user_id" unless u
    user_id = (u.is_a?(User) ? u.id : u)
    following_users.any? { |fu| fu.user_id == user_id }
  end
  
  def following_users_ids() following_users.map { |fu| fu.user_id }; end
  
  def following_users_models() following_users.map { |fu| fu.user }; end
  
  def add_follower(u, send_notification=true)
    raise ArgumentError, "must supply user" unless u and u.is_a?(User)
    
    return false if self.followed_by?(u)
  
    self.push :following_users => FollowingUser.new(:user => u).to_mongo
    u.push :roll_followings => RollFollowing.new(:roll => self).to_mongo
    
    #need to reload so the local copy is up to date for future operations
    self.reload 
    u.reload

    if send_notification
      # send email notification in a non-blocking manor
      ShelbyGT_EM.next_tick { GT::NotificationManager.check_and_send_join_roll_notification(u, self) }
    end
    
    GT::UserActionManager.follow_roll!(u.id, self.id)
  end
  
  def remove_follower(u)
    raise ArgumentError, "must supply user" unless u and u.is_a?(User)
    
    return false unless self.followed_by?(u)
    
    self.following_users.delete_if { |fu| fu.user_id == u.id }
    u.roll_followings.delete_if { |rf| rf.roll_id == self.id }
    u.rolls_unfollowed << self.id
    
    GT::UserActionManager.unfollow_roll!(u.id, self.id) if u.save and self.save
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

  def permalink() "#{Settings::ShelbyAPI.web_root}/roll/#{self.id}"; end
  
  #displayed title and thumbnail_url for upvoted rolls (aka heart rolls)
  def display_title() (self.upvoted_roll? and self.creator) ? "#{self.creator.nickname} ♥s" : self.title; end
  
  def display_thumbnail_url() self.upvoted_roll? ? "#{Settings::ShelbyAPI.web_root}/images/assets/favorite_roll_avatar.png" : self.thumbnail_url; end
  
end
