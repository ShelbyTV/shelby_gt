# encoding: UTF-8

require 'user_action_manager'

class Roll
  include MongoMapper::Document

  include Plugins::MongoMapperConfigurator
  configure_mongomapper Settings::Roll
  
  plugin MongoMapper::Plugins::IdentityMap
  
  # A Roll has many Frames, first and foremost
  many :frames, :foreign_key => :a
  
  # it was created by somebody
  belongs_to :creator,  :class_name => 'User', :required => true
  key :creator_id,      ObjectId, :required => true, :abbr => :a
  
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
  
  # The shortlinks created for each type of share, eg twitter, tumvlr, email, facebook
  key :short_links, Hash, :abbr => :g, :default => {}

  # each user following this roll and when they started following
  # for private collaborative rolls, these are the participating users
  many :following_users
  
  attr_accessible :title, :thumbnail_url

  def followed_by?(u)
    raise ArgumentError, "must supply user or user_id" unless u
    user_id = (u.is_a?(User) ? u.id : u)
    following_users.any? { |fu| fu.user_id == user_id }
  end
  
  def following_users_ids() following_users.map { |fu| fu.user_id }; end
  
  def add_follower(u)
    raise ArgumentError, "must supply user" unless u and u.is_a?(User)
    
    return false if self.followed_by?(u)
  
    self.following_users << FollowingUser.new(:user => u)
    u.roll_followings << RollFollowing.new(:roll => self)
    
    GT::UserActionManager.follow_roll!(u.id, self.id) if u.save and self.save
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

  def permalink() "#{Settings::ShelbyAPI.web_root}/roll/#{self.id}"; end
  
end
