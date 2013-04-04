# DashboardEntries are used to generate your timeline of activity, and allow it to act as an inbox.
#
# Via periodic offline processing of the actions in the system and each user's DashboardEntry array,
# we store a new set of DashboardEntrys, prioritized, with some additional information
# pertaining to why they are recommended with the given score.
#
class PrioritizedDashboardEntry
  include MongoMapper::Document

  include Plugins::MongoMapperConfigurator
  configure_mongomapper Settings::PrioritizedDashboardEntry
  
  set_collection_name "prioritized_dashboard_entries"
  
  belongs_to :dashboard_entry
  key :dashboard_entry_id,      ObjectId,   :abbr => :dbe_id
  
  # Following arrays all contain strings of ObjectIds
  
  # External sharers
  key :friend_sharers_array,  Array, :abbr => :b1, :default => [] 
  # Shelby views
  key :friend_viewers_array,  Array, :abbr => :a1, :deafult => []
  # Shelby likes
  key :friend_likers_array,   Array, :abbr => :a8, :deafult => []
  # Shelby rollers
  key :friend_rollers_array,  Array, :abbr => :a9, :deafult => []
  
  # An index exists on {_id:1, score:-1}
  key :score, Integer
  
  key :watched_by_owner, Boolean
  
  # --------- convenient scopes -----------
  scope :for_user_id, lambda { |user_id| where(:user_id => user_id) }
  scope :unwatched , where(:watched_by_owner => false)
  scope :ranked, sort(:score => -1)
  
  # --------- convenient getters -----------
  def friend_sharers() User.where(:id.in => pde.friend_sharers_array); end
  def friend_viewers() User.where(:id.in => pde.friend_viewers_array); end
  def friend_likers() User.where(:id.in => pde.friend_likers_array); end
  def friend_rollers() User.where(:id.in => pde.friend_rollers_array); end
  
  
  # --------- Mirrored From DashboardEntry ---------
  belongs_to :user, :required => true
  key :user_id, ObjectId, :abbr => :a

  # N.B. Roll is also self.frame.roll, but we keep it here for easy access
  belongs_to :roll, :required => true
  key :roll_id, ObjectId, :abbr => :b

  belongs_to :frame, :required => true
  key :frame_id, ObjectId, :abbr => :c

  # Has the user read this entry?
  key :read, Boolean, :abbr => :d

  key :action, Integer, :abbr => :e, :default => DashboardEntry::ENTRY_TYPE[:new_social_frame]

  # Denormalizing actor_id to efficiently create Prioritized Dashboard
  # Ex: Who is the poster of the Frame
  belongs_to :actor, :class_name => 'User'
  key :actor_id, ObjectId, :abbr => :f

  # Denormalizing video_id to efficiently create Prioritized Dashboard
  belongs_to :video
  key :video_id, ObjectId, :abbr => :g

  def created_at() self.id.generation_time; end
  
end
