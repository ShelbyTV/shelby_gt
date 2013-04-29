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
    :new_genius_frame => 3,
    :new_hashtag_frame => 4,
    :new_email_hook_frame => 5,
    :new_community_frame => 6,
    :re_roll => 8,
    :watch => 9,
    :comment => 10,
    :prioritized_frame => 30
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

  # Returns a link to the entry on a channel if it's a channel user's DashboardEntry
  # Otherwise return a link to the frame contained in the DashboardEntry
  def permalink()
    if channel_info = Settings::Channels.channels.find { |channel| channel["channel_user_id"] == self.user_id.to_s}
      return "#{Settings::ShelbyAPI.web_root}/channels/#{channel_info['channel_route']}/#{self.id}"
    else
      frame = self.frame
      return frame.subdomain_permalink(:require_legit_roll => true) ||
             frame.isolated_roll_permalink(:require_legit_roll => true) ||
             frame.video_page_permalink
    end
  end

end
