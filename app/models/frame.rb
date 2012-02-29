class Frame
  include MongoMapper::Document

  include Plugins::MongoMapperConfigurator
  configure_mongomapper Settings::Frame

  # A Frame is contained by exactly one Roll, first and foremost.
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
  key :score,  Integer, :required => true, :abbr => :e

  # To track the lineage of a Frame (both forward and backward), when Frame F1 gets re-rolled as F2:
  # F1.frame_children << F2
  # (F2.frame_ancestors = F1.frame_ancestors) << F1
  #
  # Track a complete lineage to the original Frame
  key :frame_ancestors, Array, :typecast => 'ObjectId', :abbr => :f
  # Track *immediate* children (but not grandchilren, &c.)
  key :frame_children, Array, :typecast => 'ObjectId', :abbr => :g
  
  
  #nothing needs to be mass-assigned (yet?)
  attr_accessible
  
end
