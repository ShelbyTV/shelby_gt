class Roll
  include MongoMapper::Document

  include Plugins::MongoMapperConfigurator
  configure_mongomapper Settings::Roll
  
  # A Roll has many Frames, first and foremost
  many :frames, :foreign_key => :a
  
  # it was created by somebody
  belongs_to :creator,  :class_name => 'User', :required => true
  key :creator_id,      ObjectId, :required => true, :abbr => :a
  
  # it has some basic categorical info
  key :title,           String, :required => true, :abbr => :b
  key :thumbnail_url,   String, :required => true, :abbr => :c

  # public rolls can be viewed, posted to, and invited to by any user (doesn't have to be following)
  # private rolls can only be viewed, posted to, and invited to by private_collaborators
  key :public,          Boolean,  :default => true,    :abbr => :d
  
  # collaborative rolls can be posted to by users other than creator, further spcified by public? (above)
  # non-collaborative rolls can only be posted to by creator
  key :collaborative,   Boolean,  :default => true,    :abbr => :e

  # each user following this roll and when they started following
  # for private collaborative rolls, these are the participating users
  many :following_users
  
  attr_accessible :title, :thumbnail_url

  def followed_by?(u)
    raise ArgumentException "must supply user or user_id" unless u
    user_id = (u.class == User ? u.id : u)
    following_users.any? { |fu| fu.user_id == user_id }
  end
  
  def add_follower(u)
    raise ArgumentException "must supply user" unless u and u.class == User
    
    self.following_users << FollowingUser.new(:user => u)
    u.roll_followings << RollFollowing.new(:roll => self)
  end
  
  # Anybody can view a public roll
  # Creator of a roll can always view it
  # Private rolls are only viewable by followers
  def viewable_by?(u)
    raise ArgumentException "must supply user or user_id" unless u
    user_id = (u.class == User ? u.id : u)
    
    return true if self.public?
    
    return true if self.creator_id == user_id
    
    #private roll user didn't create, must be a follower to view
    return self.following_users.any? { |fu| fu.user_id == user_id }
  end

  # Only creator can post to a non-collaborative roll
  # Anybody can post to public collaborative roll
  # Only followers can post to private, collaborative roll
  def postable_by?(u)
    raise ArgumentException "must supply user or user_id" unless u
    user_id = (u.class == User ? u.id : u)
    
    return true if self.creator_id == user_id
    
    return false unless self.collaborative?
    
    return true if self.public?
    
    # private collaborative roll, must be a follower to post
    return self.following_users.any? { |fu| fu.user_id == user_id }
  end

  # if you can view it, you can invite to it
  def invitable_to_by?(u) viewable_by?(u); end

end
