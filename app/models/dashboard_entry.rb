# DashboardEntries are used to generate your timeline of activity, and allow it to act as an inbox.
# There will be entries for new videos, comments where i'm participating, watches, &c.

class DashboardEntry
  include MongoMapper::Document

  include Plugins::MongoMapperConfigurator
  configure_mongomapper Settings::DashboardEntry
  
  belongs_to :user, :required => true
  key :user_id, ObjectId, :abbr => :a

  # N.B. Roll is also self.frame.roll, but we keep it here for easy access
  belongs_to :roll, :required => true
  key :roll_id, ObjectId, :abbr => :b  
  
  belongs_to :frame, :required => true
  key :frame_id, ObjectId, :abbr => :c

  # Has the user read this entry?
  key :read, Boolean, :abbr => :d
  
  # What does this entry represent (re-roll, watch, comment)?
  # [using integers instead of strings to keep the size as small as possible]
  ENTRY_TYPE = {
    :new_social_frame => 0,
    :new_bookmark_frame => 1,
    :new_in_app_frame => 2,
    :re_roll => 8,
    :watch => 9,
    :comment => 10
  }.freeze
  key :action, Integer, :abbr => :e, :default => ENTRY_TYPE[:new_social_frame]

  # If this was an action other than new_*_frame, what Shelbyer was it?
  belongs_to :actor
  key :actor_id, ObjectId, :abbr => :f
  
  attr_accessible :read
  
  def created_at() self.id.generation_time; end

end
