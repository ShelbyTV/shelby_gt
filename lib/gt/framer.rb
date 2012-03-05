# This is the one and place where Frames are created.
#
# If the user re-rolls a Frame, that goes through us.
# If Arnold 2, the bookmarklet, or a dev script needs to create a Frame, that goes through us.
#
module GT
  class Framer

    # Creates a Frame with Conversation & associated DashboardEntries.  
    #  If adding to a Roll, create DashboardEntries for all followers of Roll.
    #  If not adding to a Roll, create single DashboardEntry for the given dashboard owner.
    #
    #
    # --options--
    #
    # :creator => User --- REQUIRED the 'owner' or 'creator' of this Frame (ie who tweeted it?)
    # :video => Video --- REQUIRED (may be new or persisted) the normalized video being referenced
    # :message => Message --- OPTIONAL (must be new) which is either normalized twitter/fb stuff, or straight from app, or blank
    #                       - will be added to a new Conversation attached to the Roll
    #                       - see GT::<Twitter | Facebook | Tumblr>Normalizer to create the messages
    # :roll => Roll --- OPTIONAL: when given, add this new Frame to the given Roll and add DashboardEntries for each follower of the Roll
    # :dashboard_user_id => id --- OPTIONAL: if no roll is given, will add the new Frame to a DashboardEntry for this user_id
    #                            - N.B. does *not* check that the given id is for a valid User
    # :action => DashboardEntry::ENTRY_TYPE[?] --- REQUIRED: what action created this frame? Distinguish between social, bookmark
    #
    # --returns--
    #
    # { :frame => newly_created_frame, :dashboard_entries => [1 or more DashboardEntry, ...] }
    #
    def self.create_frame!(options)
      raise ArgumentError, "must supply a :creator" unless (creator = options.delete(:creator)).is_a? User
      raise ArgumentError, "must supply a :video" unless (video = options.delete(:video)).is_a? Video
      raise ArgumentError, "must supply an :action" unless DashboardEntry::ENTRY_TYPE.values.include?(action = options.delete(:action))
      roll = options.delete(:roll)
      dashboard_user_id = options.delete(:dashboard_user_id)
      raise ArgumentError, "must include a :roll or :dashboard_user_id" unless roll.is_a?(Roll) or dashboard_user_id.is_a?(BSON::ObjectId)
      message = options.delete(:message)
      
      res = { :frame => nil, :dashboard_entries => [] }
      
      # Frame
      # There will always be exactly 1 new frame (we're persisting here, hence the ! in the method name)
      f = Frame.new
      f.creator = creator
      f.video = video
      f.roll = roll if roll
      f.conversation = Conversation.new
      f.conversation.messages << message if message
      f.save
      res[:frame] = f
      
      # DashboardEntry
      # We need dashboard entries for the roll's followers or the given dashboard_user_id
      user_ids = []
      user_ids << dashboard_user_id if dashboard_user_id
      user_ids += roll.following_users.map { |fu| fu.user_id } if roll
      
      user_ids.uniq.each do |user_id|
        dbe = DashboardEntry.new
        dbe.user_id = user_id
        dbe.roll = roll
        dbe.frame = res[:frame]
        dbe.action = action
        dbe.save
        res[:dashboard_entries] << dbe
      end
      
      return res
    end
    
    # Roll the given Frame for the User into the new Roll
    # orig_frame must be a Frame proper
    # for_user must be a User or the id of a user
    # to_roll must be a Roll or the id of a roll
    #
    # RETURNS: the newly re-rolled Frame
    # SIDE EFFECTS: orig_frame.frame_children will be updated with the new Frame
    #
    def self.re_roll(orig_frame, for_user, to_roll)
      raise ArgumentError, "must supply user or user_id" unless for_user
      user_id = (for_user.is_a?(User) ? for_user.id : for_user)

      raise ArgumentError, "must supply roll or roll_id" unless to_roll
      roll_id = (to_roll.is_a?(Roll) ? to_roll.id : to_roll)

      return basic_re_roll(orig_frame, user_id, roll_id)
    end
    
    private
      
      def self.basic_re_roll(orig_frame, user_id, roll_id)
        # Set up the basics
        new_frame = Frame.new
        new_frame.creator_id = user_id
        new_frame.roll_id = roll_id
        new_frame.video_id = orig_frame.video_id

        # Create a new conversation
        convo = Conversation.new
        convo.video_id = new_frame.video_id
        convo.public = true
        new_frame.conversation = convo

        # Track the lineage
        new_frame.frame_ancestors = orig_frame.frame_ancestors.clone
        new_frame.frame_ancestors << orig_frame.id
        orig_frame.frame_children << new_frame.id

        return new_frame
      end
    
  end
end
    
    