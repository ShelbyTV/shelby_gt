require 'framer'
require 'user_action_manager'

class Frame
  include MongoMapper::Document

  include Plugins::MongoMapperConfigurator
  configure_mongomapper Settings::Frame

  # A Frame is contained by exactly one Roll, first and foremost.
  # In some special cases, a Frame may *not* have a Roll (ie a private Facebook post creates a Frame that only attaches to DashboardEntry)
  belongs_to :roll, :required => true
  key :roll_id, ObjectId, :abbr => :a
  
  # It must reference a video, post, and creator
  belongs_to :video, :required => true
  key :video_id, ObjectId, :abbr => :b
  
  belongs_to :conversation, :required => true
  key :conversation_id, ObjectId, :abbr => :c
  
  belongs_to :creator,  :class_name => 'User', :required => true
  key :creator_id,      ObjectId,   :abbr => :d
  
  # Frames will be ordered in Rolls based on their score
  key :score,  Float, :required => true, :abbr => :e
  
  # The users who have upvoted, increasing the score
  key :upvoters, Array, :typecase => ObjectId, :abbr => :f

  # To track the *re-roll* lineage of a Frame (both forward and backward); when Frame F1 gets re-rolled as F2:
  # F1.frame_children << F2
  # F2.frame_ancestors = (F1.frame_ancestors << F1)
  #
  # N.B. when a Frame is duped (ie. to be put on WatchLater, Upvoted, or Viewed) we track the new Frame's ancestors, but do not add that new
  #      dupe Frame to the children of the original, as it's not a re-roll.
  #
  # Track a complete lineage to the original Frame
  key :frame_ancestors, Array, :typecast => 'ObjectId', :abbr => :g
  # Track *immediate* children (but not grandchilren, &c.)
  key :frame_children, Array, :typecast => 'ObjectId', :abbr => :h
  
  
  #nothing needs to be mass-assigned (yet?)
  attr_accessible
  
  before_validation :update_score
  
  def created_at() self.id.generation_time; end
  
  #------ ReRolling -------
  
  #re roll this frame into the given roll, for the given user
  def re_roll(user, roll)
    return GT::Framer.re_roll(self, user, roll)
  end
  
  #------ Viewing
  
  #TODO: on view, add to users viewed roll (unless already copied in there)
  
  #------ WatchLater ------
  
  #TODO: on view, add to users viewed roll
  
  #------ Voting -------
  
  def upvote(u)
    raise ArgumentError, "must supply user or user_id" unless u
    user_id = (u.is_a?(User) ? u.id : u)
    
    return false if self.has_voted?(user_id)
    
    self.upvoters << user_id
    #TODO: dupe this frame into u.upvoted_roll
  
    update_score
    
    #TODO: this should be done by controller, not in here
    GT::UserActionManager.upvote!(u.id, self.id) if u.save
  
    true
  end
  
  def has_voted?(u)
    raise ArgumentError, "must supply user or user_id" unless u
    user_id = (u.is_a?(User) ? u.id : u)
    
    return self.upvoters.any? { |uid| uid == user_id }
  end
  
  private
    
    # Score increases linearly with time, logarithmically with votes
    # 10 votes = 1/2 day worth of points
    # 100 votes = 1 day worth of points
    def update_score
      #each second = .00002
      #each hour = .08
      #each day = 2
      time_score =(self.created_at.to_f - SHELBY_EPOCH.to_f) / TIME_DIVISOR
      
      #+ log10 each upvote
      # 10 votes = 1 point
      # 100 votes = 10 points
      vote_score = Math.log10([1, self.upvoters.size].max)
      
      self.score = time_score + vote_score
    end
    
    SHELBY_EPOCH = Time.utc(2012,2,22)
    TIME_DIVISOR = 45_000.0
  
end
