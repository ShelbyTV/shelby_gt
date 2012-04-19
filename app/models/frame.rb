require 'framer'
require 'user_action_manager'
require 'notification_manager'

class Frame
  include MongoMapper::Document

  include Plugins::MongoMapperConfigurator
  configure_mongomapper Settings::Frame
  
  plugin MongoMapper::Plugins::IdentityMap

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
  key :frame_ancestors, Array, :typecast => 'ObjectId', :abbr => :g, :default => []
  # Track *immediate* children (but not grandchilren, &c.)
  key :frame_children, Array, :typecast => 'ObjectId', :abbr => :h, :default => []
  
  # Each time a new view is counted (see #view!) we increment this and video.view_count
  key :view_count, Integer, :abbr => :i, :default => 0
  
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
  
  # Will add this Frame to the User's viewed_roll if they haven't "viewed" this in the last 24 hours.
  # Also updates the view_count on this frame and it's video
  def view!(u)
    raise ArgumentError, "must supply User" unless u and u.is_a?(User)
    
    # If this Frame hasn't been added to the user's viewed_roll in the last X hours, dupe it now
    if Frame.roll_includes_ancestor_of_frame?(u.viewed_roll_id, self.id, 24.hours.ago)
      return false
    else
      #update view counts and add dupe for this 'viewing'
      Frame.increment(self.id, :view_count => 1)
      Video.increment(self.video_id, :view_count => 1)

      # when a frame.video.reload happens we want to get the real doc that is reloaded, not the cached one.
      MongoMapper::Plugins::IdentityMap.clear

      return GT::Framer.dupe_frame!(self, u.id, u.viewed_roll_id)
    end
  end
  
  #------ Watch Later ------
  
  def add_to_watch_later!(u)
    raise ArgumentError, "must supply User" unless u and u.is_a?(User)
    
    #if it's already in this user's watch later, just return that
    if prev_dupe = Frame.get_ancestor_of_frame(u.watch_later_roll_id, self.id)
      return prev_dupe
    else
      return GT::Framer.dupe_frame!(self, u.id, u.watch_later_roll_id)
    end
  end
  
  # To remove from watch later, destroy the Frame! (don't forget to add a UserAction)
  
  #------ Voting -------
  
  def upvote!(u)
    raise ArgumentError, "must supply User" unless u and u.is_a?(User)
    
    return false if self.has_voted?(u.id)
    
    self.upvoters << u.id
    
    GT::Framer.dupe_frame!(self, u.id, u.upvoted_roll_id)
    
    update_score
    
    # send email notification in a non-blocking manor
    EM.next_tick { GT::NotificationManager.check_and_send_upvote_notification(u, self) }
    
    self.save
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
    
    # Checks for a Frame, with the given roll_id, where frame_ancestors contains frame_id
    #
    # DANGEROUS - This has to walk the DB!  It will use the index on Frame.roll_id, but that's it.
    #             We set created_after to ensure Mongo doesn't have to walk too far, but it will walk,
    #             checking each frame_ancestors array to see if it contains frame_id
    def self.roll_includes_ancestor_of_frame?(roll_id, frame_id, created_after)
      raise ArgumentError, "must supply roll_id" unless roll_id and (roll_id.is_a?(String) or roll_id.is_a?(BSON::ObjectId))
      raise ArgumentError, "must supply frame_id" unless frame_id and (frame_id.is_a?(String) or frame_id.is_a?(BSON::ObjectId))
      raise AagumentError, "must supply valid time" unless created_after.is_a? Time

      Frame.where( 
        :roll_id => roll_id, 
        :_id.gt => BSON::ObjectId.from_time(created_after),
        :frame_ancestors => frame_id
        ).exists?
    end
    
    # Gets a Frame, with the given roll_id, where frame_ancestors contains frame_id
    #
    # DANGEROUS - This has to walk the DB!  It will use the index on Frame.roll_id, but that's it.
    #             We are assuming the Frame's in user.watch_later_roll will be in the working set and/or small in number, making this safe.s
    def self.get_ancestor_of_frame(roll_id, frame_id)
      raise ArgumentError, "must supply roll_id" unless roll_id and (roll_id.is_a?(String) or roll_id.is_a?(BSON::ObjectId))
      raise ArgumentError, "must supply frame_id" unless frame_id and (frame_id.is_a?(String) or frame_id.is_a?(BSON::ObjectId))

      Frame.where( 
        :roll_id => roll_id,
        :frame_ancestors => frame_id
        ).first
    end
  
end
