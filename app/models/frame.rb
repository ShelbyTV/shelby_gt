require 'framer'
require 'user_action_manager'
require 'notification_manager'

class Frame
  include MongoMapper::Document

  include Plugins::MongoMapperConfigurator
  configure_mongomapper Settings::Frame

  # A Frame is contained by exactly one Roll, first and foremost.
  # In some special cases, a Frame may *not* have a Roll (ie a private Facebook post creates a Frame that only attaches to DashboardEntry)
  belongs_to :roll, :required => true
  key :roll_id, ObjectId, :abbr => :a
  # When "destroyed" we actually just nil out the roll_id so the Frame stops getting returned
  key :deleted_from_roll_id, ObjectId, :abbr => :l

  # It must reference a video, post, and creator
  belongs_to :video, :required => true
  key :video_id, ObjectId, :abbr => :b

  belongs_to :conversation, :required => true
  key :conversation_id, ObjectId, :abbr => :c

  belongs_to :creator,  :class_name => 'User'
  key :creator_id,      ObjectId,   :abbr => :d

  # When we don't have a creator (ie. email-only discussion roll user) store some identifying name
  key :anonymous_creator_nickname, String, :abbr => :m

  # Frames will be ordered in normal Rolls based on their score by default
  key :score,  Float, :required => true, :abbr => :e

  # The users who have upvoted, increasing the score
  key :upvoters, Array, :typecast => 'ObjectId', :abbr => :f, :default => []

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

  # The shortlinks created for each type of share, eg twitter, tumvlr, email, facebook
  key :short_links, Hash, :abbr => :j, :default => {}

  # Manual ordering value. Used as the default ordering for genius roll frames. May be used in the future for user-initiated ordering.
  key :order, Float, :default => 0, :abbr => :k

  # Total number of likes - both by upvoters (logged in likers) and logged out likers
  key :like_count, Integer, :abbr => :n, :default => 0

  #nothing needs to be mass-assigned (yet?)
  attr_accessible

  before_validation(:on => :create) { self.update_score if self.new? }

  after_create :increment_rolls_frame_count

  def created_at() self.id.generation_time; end

  #------ Permissions -------

  #N.B. Destroy does not actually remove the record from the DB, #destroy below
  def destroyable_by?(user)
    return !!(user.is_admin? or self.creator == nil or self.creator == user or (self.roll and self.roll.creator == user))
  end

  #------ ReRolling -------

  #re roll this frame into the given roll, for the given user
  def re_roll(user, roll)
    return GT::Framer.re_roll(self, user, roll)
  end

  #------ Viewing

  # Will add this Frame to the User's viewed_roll if they haven't "viewed" this in the last day.
  # Also updates the view_count on this frame and it's video regardless if user is passed in
  #
  # Returns false if view was recently recorded, otherwise returns this frame or the dupe when created
  def view!(u)
    raise ArgumentError, "must supply valid User Object or nil" unless u.is_a?(User) or u.nil?

    if u and Frame.roll_includes_ancestor_of_frame?(u.viewed_roll_id, self.id, 1.day.ago)
      # This Frame has been added to the user's viewed_roll in the last 1 day, ignore this view
      return false
    end

    # Always update view counts and reload self
    Frame.increment(self.id, :i => 1)        # :view_count is :i in Frame
    Video.increment(self.video_id, :q => 1)  # :view_count is :q in Video

    # when a frame.video.reload happens we want to get the real doc that is reloaded, not the cached one.
    MongoMapper::Plugins::IdentityMap.clear if Settings::Frame.mm_use_identity_map

    if u.nil?
      return self
    else
      ShelbyGT_EM.next_tick { GT::OpenGraph.send_action('watch', u, self) }
      # Add this frame to users viewed_roll so we don't double-count view later
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
      Frame.collection.update({:_id => self.id}, {
        :$addToSet => {:f => u.id},
        :$inc => {:n => 1}
      })
      self.reload
      self.update_score
      self.save

      # send email notification in a non-blocking manor
      ShelbyGT_EM.next_tick { GT::NotificationManager.check_and_send_like_notification(self, u) }

      # add this frame to the community channel in a non-blocking manner
      ShelbyGT_EM.next_tick { add_to_community_channel }

      return GT::Framer.dupe_frame!(self, u.id, u.watch_later_roll_id)
    end
  end

  #------ Like ------

  # for now just increment the like_count
  # NB: add_to_watch_later! does this too, but not through this method
  #   because it performs other updates at the same time in one atomic DB operation
  def like!()
    Frame.collection.update({:_id => self.id}, {:$inc => {:n => 1}})
    self.reload
    # send email notification in a non-blocking manor
    ShelbyGT_EM.next_tick { GT::NotificationManager.check_and_send_like_notification(self) }
    # add this frame to the community channel in a non-blocking manner
    ShelbyGT_EM.next_tick { add_to_community_channel }
  end

  # To remove from watch later, destroy the Frame! (don't forget to add a UserAction)

  #------ Voting -------

  def upvote!(u)
    raise ArgumentError, "must supply User" unless u and u.is_a?(User)

    return true if self.has_voted?(u.id)

    self.upvoters << u.id

    GT::Framer.dupe_frame!(self, u.id, u.upvoted_roll_id)

    update_score

    # send email notification in a non-blocking manor
    ShelbyGT_EM.next_tick { GT::NotificationManager.check_and_send_upvote_notification(u, self) }

    self.save
  end

  def upvote_undo!(u)
    raise ArgumentError, "must supply User" unless u and u.is_a?(User)

    return true unless self.has_voted?(u.id)

    self.upvoters.delete_if { |id| id == u.id }

    GT::Framer.remove_dupe_of_frame_from_roll!(self, u.upvoted_roll_id)

    update_score

    self.save
  end

  def has_voted?(u)
    raise ArgumentError, "must supply user or user_id" unless u
    user_id = (u.is_a?(User) ? u.id : u)

    return self.upvoters.any? { |uid| uid == user_id }
  end

  # Returns a link to the subdomain when it's a legit roll
  # Otherwise links to the SEO page
  def permalink()
    return self.subdomain_permalink(:require_legit_roll => true) || self.video_page_permalink
  end

  # set {:require_legit_roll => true} to get a subdomain link only for a legit roll, otherwise nil
  def subdomain_permalink(options={})
    return nil unless self.roll_id and subdomain = self.roll.subdomain

    if options[:require_legit_roll]
      return nil unless [ Roll::TYPES[:special_public_real_user],
                          Roll::TYPES[:special_public_upgraded],
                          Roll::TYPES[:user_public],
                          Roll::TYPES[:global_public]
                        ].include? self.roll.roll_type
    end

    return "http://#{subdomain}.#{Settings::ShelbyAPI.web_domain}/#{self.id}"
  end

  # set {:require_legit_roll => true} to get an isolated-roll link only for a legit roll, otherwise nil
  def isolated_roll_permalink(options={})
    return nil unless self.roll_id and self.roll.id

    if options[:require_legit_roll]
      return nil unless [ Roll::TYPES[:special_public_real_user],
                          Roll::TYPES[:special_public_upgraded],
                          Roll::TYPES[:user_public],
                          Roll::TYPES[:global_public]
                        ].include? self.roll.roll_type
    end

    return "http://#{Settings::ShelbyAPI.web_domain}/isolated-roll/#{self.roll.id}/frame/#{self.id}"
  end

  # Return a link to video SEO page
  # Falls back to direct frame/roll link when video can't be found
  def video_page_permalink()
    if video = self.video
      "#{Settings::ShelbyAPI.web_root}/video/#{video.provider_name}/#{video.provider_id}/?frame_id=#{self.id}"
    elsif self.roll_id
      "#{Settings::ShelbyAPI.web_root}/roll/#{self.roll_id}/frame/#{self.id}"
    else
      "#{Settings::ShelbyAPI.web_root}/rollFromFrame/#{self.id}"
    end
  end

  # this is for logged-in users, so we link to roll/:id/frame/:id/comments
  def permalink_to_frame_comments()
    if self.roll_id
      "#{Settings::ShelbyAPI.web_root}/roll/#{self.roll_id}/frame/#{self.id}/comments"
    else
      "#{Settings::ShelbyAPI.web_root}/rollFromFrame/#{self.id}/comments"
    end
  end

  #------ Lifecycle -------

  # Generally not great to destroy actual data, things get messy and broken.
  # By moving roll_id into deleted_from_roll_id, we prevent this Frame from being returned with the Roll,
  # but we allow other API calls that reference the frame by ID to continue working.
  # (ie. Commenting, DashboardEntries, upvoting, watched, etc.)
  def destroy
    roll = self.roll

    # move roll_id into deleted_from_roll_id and save
    self.deleted_from_roll_id = self.roll_id
    self.roll_id = nil
    self.save(:validate => false)

    #update the roll (on DB and in memory if loaded)
    Roll.decrement(self.deleted_from_roll_id, :j => -1) if self.deleted_from_roll_id
    roll.frame_count -= 1 if roll

    #if this frame is on a watch later roll, undo the upvote that resulted from its addition to the roll
    if roll.roll_type == Roll::TYPES[:special_watch_later]
      # the original frame that was upvoted when this frame was created on the watch later roll is this frame's
      # direct (last) ancestor
      if upvoted_frame_id = self.frame_ancestors.last
        # the person whose watch later roll this is was the upvoter, so
        # 1) remove him/her from the ancestor frame's upvoters array
        # 2) update (decrement) the ancestor frame's like_count accordingly
        Frame.collection.update({:_id => upvoted_frame_id}, {
          :$pull => {:f => roll.creator.id},
          :$inc => {:n => -1}
        })
        # 3) recalculate the ancestor frame's score
        MongoMapper::Plugins::IdentityMap.clear if Settings::Frame.mm_use_identity_map
        if upvoted_frame = Frame.find(upvoted_frame_id)
          upvoted_frame.update_score
          upvoted_frame.save
        end
      end
    end

    true
  end

  def virtually_destroyed?() self.deleted_from_roll_id != nil; end

  # Score increases linearly with time, logarithmically with votes
  # 10 votes = 1/2 day worth of points
  # 100 votes = 1 day worth of points
  def update_score
    #each second = .00002
    #each hour = .08
    #each day = 2
    time_score =(self.created_at.to_f - SHELBY_EPOCH.to_f) / TIME_DIVISOR
    like_score = self.calculate_like_score
    self.score = time_score + like_score
  end

  def calculate_like_score
    #+ log10 each like
    # add 1 so that zero likes is zero points and 1 like makes a measurable difference
    # 0 likes = 0 points
    # 1 like = 1 point
    # 10 likes = 2 points
    # 100 likes = 3 points
    [Math.log10(self.like_count), -1.0].max + 1.0
  end

  private

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

    # Rolls' :frame_count is abbreviated as :j and that doesn't get translated w/ atomic updates like this...
    # N.B. Roll.increment doesn't udpate the roll locally, and we don't want to overwrite that if we save this roll to the DB
    def increment_rolls_frame_count
      Roll.increment(self.roll_id, :j => 1) if self.roll_id
      self.roll.frame_count += 1 if self.roll
      true
    end

    # look up the community channel user in the db, and add a dashboard entry
    # for that user containing this frame
    def add_to_community_channel
      if community_channel_user = User.find(Settings::Channels.community_channel_user_id)
        GT::Framer.create_dashboard_entry(self, ::DashboardEntry::ENTRY_TYPE[:new_community_frame], community_channel_user)
      end
    end

end
