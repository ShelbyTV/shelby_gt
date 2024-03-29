# DashboardEntries are used to generate your timeline of activity, and allow it to act as an inbox.
# There will be entries for new videos, comments where i'm participating, watches, &c.

class DashboardEntry
  include MongoMapper::Document

  include Plugins::MongoMapperConfigurator
  configure_mongomapper Settings::DashboardEntry



  belongs_to :user, :required => true
  key :user_id, ObjectId, :abbr => :a

  # N.B. Roll is also self.frame.roll, but we keep it here for easy access
  belongs_to :roll
  key :roll_id, ObjectId, :abbr => :b

  belongs_to :frame
  key :frame_id, ObjectId, :abbr => :c

  # if part of the contents of the entry or the action originated from some other
  # frame, that frame is referenced here as src_frame
  belongs_to :src_frame, :class_name => 'Frame'
  key :src_frame_id, ObjectId, :abbr => :i

  # if part of the contents of the entry or the action originated from some other
  # video, that video is referenced here as src_video
  belongs_to :src_video, :class_name => 'Video'
  key :src_video_id, ObjectId, :abbr => :j

  # if the entry originated from a PrioritizedDashboardEntry, that
  # entry's friend arrays are copied here for easy access
  # Following arrays all contain strings of ObjectIds

  # External sharers
  key :friend_sharers_array,          Array, :abbr => :a1,  :default => []
  # Shelby views
  key :friend_viewers_array,          Array, :abbr => :a2,  :default => []
  # Shelby likes
  key :friend_likers_array,           Array, :abbr => :a3,  :default => []
  # Shelby rollers
  key :friend_rollers_array,          Array, :abbr => :a4,  :default => []
  # Shelby complete views
  key :friend_complete_viewers_array, Array, :abbr => :a5,  :default => []

  # --------- convenient getters -----------
  def all_associated_friends
    friend_ids = self.friend_sharers_array + self.friend_viewers_array + self.friend_likers_array + self.friend_rollers_array + self.friend_complete_viewers_array
    User.find(friend_ids.uniq)
  end

  # Has the user read this entry?
  key :read, Boolean, :abbr => :d, :default => false

  # What does this entry represent (re-roll, watch, comment)?
  # [using integers instead of strings to keep the size as small as possible]
  ENTRY_TYPE = {
    :new_social_frame => 0,
    :new_bookmark_frame => 1,
    :new_in_app_frame => 2,
    :new_genius_frame => 3,
    :new_hashtag_frame => 4,
    :new_email_hook_frame => 5,
    :new_community_frame => 6,
    :re_roll => 8,
    :watch => 9,
    :comment => 10,
    :like_notification => 11,
    :anonymous_like_notification => 12,
    :share_notification => 13,
    :follow_notification => 14,
    :prioritized_frame => 30,
    :video_graph_recommendation => 31,
    :entertainment_graph_recommendation => 32,
    :mortar_recommendation => 33,
    :channel_recommendation => 34
  }.freeze
  key :action, Integer, :abbr => :e, :default => ENTRY_TYPE[:new_social_frame]

  # Denormalizing actor_id to efficiently create Prioritized Dashboard
  # Ex: Who is the poster of the Frame
  belongs_to :actor, :class_name => 'User'
  key :actor_id, ObjectId, :abbr => :f

  # Denormalizing video_id to efficiently create Prioritized Dashboard
  belongs_to :video
  key :video_id, ObjectId, :abbr => :g

  # The shortlinks created for each type of share, eg twitter, tumblr, email, facebook
  key :short_links, Hash, :abbr => :h, :default => {}

  attr_accessible :read

  def created_at() self.id.generation_time; end

  # Returns a link to the entry at '/community/entry_id' if the entry is on the community channel
  # Otherwise return a link to the frame contained in the DashboardEntry
  def permalink()
    # notifications don't have permalinks (yet?)
    return if self.is_notification?

    if channel_info = Settings::Channels.channels.find { |channel| channel["channel_user_id"] == self.user_id.to_s}
      if channel_info['channel_route'] == 'community'
        return "#{Settings::ShelbyAPI.web_root}/community/#{self.id}"
      end
    end

    return self.frame.permalink
  end

  # @return [Boolean] Whether the entry is a video recommendation
  def is_recommendation?()
    self.action && (self.action >= ENTRY_TYPE[:video_graph_recommendation]) && (self.action <= ENTRY_TYPE[:channel_recommendation])
  end

  # @return [Boolean] Whether the entry is a notification
  def is_notification?()
    self.action && (self.action >= ENTRY_TYPE[:like_notification]) && (self.action <= ENTRY_TYPE[:follow_notification])
  end

end
