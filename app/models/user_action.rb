# A FrameAction occurs when a user upvotes or views a Frame.
# Viewing is tracked with start-end times, so this is a write-heavy DB.

class UserAction
  include MongoMapper::Document

  include Plugins::MongoMapperConfigurator
  configure_mongomapper Settings::UserAction

  key :type, Integer, :abbr => :a, :required => true
  TYPES = {
    :view => 1,
    :upvote => 2,
    :unupvote => 3,
    :follow_roll => 4,
    :unfollow_roll => 5,
    :watch_later => 6,
    :unwatch_later => 7,
    :like => 8,
    :roll => 9
    }.freeze

  # May not have user if this is a play by a non-logged in user
  belongs_to :user
  key :user_id, ObjectId, :abbr => :b

  # for :view, :upvote, :unupvote, :watch_later and :unwatch_later
  # N.B. This references *original* frame (not the re-rolled one)
  belongs_to :frame
  key :frame_id, ObjectId, :abbr => :c
  belongs_to :video
  key :video_id, ObjectId, :abbr => :d

  # for :follow_roll and :unfollow_roll
  belongs_to :roll
  key :roll_id, ObjectId, :abbr => :e

  # track when this view started/stopped
  key :start_s, Integer, :abbr => :f
  key :end_s, Integer, :abbr => :g

  #---validations---

  #ROLL
  validates_presence_of [:user_id, :roll_id, :frame_id, :video_id], :if => Proc.new { |ua| ua.type == TYPES[:roll] }
  #VIEW
  validates_presence_of [:start_s, :end_s, :frame_id, :video_id], :if => Proc.new { |ua| ua.type == TYPES[:view] }
  #UPVOTE
  validates_presence_of [:user_id, :frame_id], :if => Proc.new { |ua| ua.type.in? [TYPES[:upvote], TYPES[:unupvote]] }
  #FOLLOW
  validates_presence_of [:user_id, :roll_id], :if => Proc.new { |ua| ua.type.in? [TYPES[:follow_roll], TYPES[:unfollow_roll]] }
  #WATCH_LATER
  validates_presence_of [:user_id, :frame_id], :if => Proc.new { |ua| ua.type.in? [TYPES[:watch_later], TYPES[:unwatch_later]] }

end