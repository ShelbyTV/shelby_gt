# This is the one and only place where Frames are created.
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
    # N.B. If a conversation with a message with the same origin_id exists, conversation save will fail and this
    #  will return false.  This prevents timing issues between threads receiving the same tweets for different observers.
    #
    # --options--
    #
    # :creator => User --- OPTIONAL the 'owner' or 'creator' of this Frame (ie who tweeted it?)
    #
    # Either :video or :video_id is required, but not both:
    # :video => Video --- REQUIRED (may be new or persisted) the normalized video being referenced
    # :video_id => Video ID --- REQUIRED (may be new or persisted) the normalized video ID being referenced
    #
    # :message => Message --- OPTIONAL (must be new) which is either normalized twitter/fb stuff, or straight from app, or blank
    #                       - will be added to a new Conversation attached to the Roll
    #                       - see GT::<Twitter | Facebook | Tumblr>Normalizer to create the messages
    # :roll => Roll --- OPTIONAL: when given, add this new Frame to the given Roll and add DashboardEntries for each follower of the Roll
    # :dashboard_user_id => id --- OPTIONAL: if no roll is given, will add the new Frame to a DashboardEntry for this user_id
    #                            - N.B. does *not* check that the given id is for a valid User
    # :action => DashboardEntry::ENTRY_TYPE[?] --- REQUIRED: what action created this frame? Distinguish between social, bookmark
    # :score => Float --- OPTIONAL initial score for ordering the frames in a roll
    # :order => Float --- OPTIONAL manual ordering for genius rolls
    #
    # --returns--
    #
    # false if message.origin_id already exists in DB's unique index
    # { :frame => newly_created_frame, :dashboard_entries => [1 or more DashboardEntry, ...] }
    #
    def self.create_frame(options)
      creator = options.delete(:creator)
      score = options.delete(:score)
      order = options.delete(:order)
      video = options.delete(:video)
      video_id = options.delete(:video_id)
      raise ArgumentError, "must include a :video or :video_id" unless video.is_a?(Video) or video_id.is_a?(BSON::ObjectId)
      raise ArgumentError, "must not supply both :video and :video_id" if (video and video_id)
      raise ArgumentError, "must supply an :action" unless DashboardEntry::ENTRY_TYPE.values.include?(action = options.delete(:action))
      roll = options.delete(:roll)
      dashboard_user_id = options.delete(:dashboard_user_id)
      raise ArgumentError, "must include a :roll or :dashboard_user_id" unless roll.is_a?(Roll) or dashboard_user_id.is_a?(BSON::ObjectId)
      message = options.delete(:message)
      raise ArgumentError, ":message must be a Message" if message and !message.is_a?(Message)
      
      # Try to safely create conversation
      convo = Conversation.new
      convo.from_deeplink = true if options.delete(:deep)
      convo.video = video if video
      convo.video_id = video_id if video_id
      if message
        convo.messages << message
        convo.public = message.public
      end
      begin
        convo.save(:safe => true)
      rescue Mongo::OperationFailure
        # unique key failure due to duplicate
        return false
      end
      
      res = { :frame => nil, :dashboard_entries => [] }
      
      # Frame
      # There will always be exactly 1 new frame
      f = Frame.new
      f.creator = creator
      f.video = video if video
      f.video_id = video_id if video_id 
      f.roll = roll if roll
      f.conversation = convo
      f.score = score
      f.order = order

      f.save
 
      #track the original frame in the convo
      convo.update_attribute(:frame_id, f.id)
      
      res[:frame] = f
      
      # DashboardEntry
      # We need dashboard entries for the roll's followers or the given dashboard_user_id
      user_ids = []
      user_ids << dashboard_user_id if dashboard_user_id
      user_ids += roll.following_users_ids if roll
      
      res[:dashboard_entries] = create_dashboard_entries(f, action, user_ids)
      
      # Roll - set its thumbnail if missing
      ensure_roll_metadata!(roll, f) if roll
      
      return res
    end
    
    # Roll the given Frame for the User into the new Roll
    # orig_frame must be a Frame proper
    # for_user must be a User or the id of a user
    # to_roll must be a Roll or the id of a roll
    #
    # SIDE EFFECTS: orig_frame.frame_children will be updated with the new Frame
    #
    # --returns--
    #
    # { :frame => newly_created_frame, :dashboard_entries => [1 or more DashboardEntry, ...] }
    #
    def self.re_roll(orig_frame, for_user, to_roll)
      raise ArgumentError, "must supply user or user_id" unless for_user
      user_id = (for_user.is_a?(User) ? for_user.id : for_user)

      raise ArgumentError, "must supply roll or roll_id" unless to_roll
      roll_id = (to_roll.is_a?(Roll) ? to_roll.id : to_roll)
      
      res = { :frame => nil, :dashboard_entries => [] }

      res[:frame] = basic_re_roll(orig_frame, user_id, roll_id)
      
      #create dashboard entries for all roll followers *except* the user who just re-rolled
      res[:dashboard_entries] = create_dashboard_entries(res[:frame], DashboardEntry::ENTRY_TYPE[:re_roll], to_roll.following_users_ids - [user_id])
      
      # Roll - set its thumbnail if missing
      ensure_roll_metadata!(Roll.find(roll_id), res[:frame])
      
      return res
    end
    
    def self.dupe_frame!(orig_frame, for_user, to_roll)
      raise ArgumentError, "must supply original Frame" unless orig_frame and orig_frame.is_a? Frame
      
      raise ArgumentError, "must supply user or user_id" unless for_user
      user_id = (for_user.is_a?(User) ? for_user.id : for_user)

      raise ArgumentError, "must supply roll or roll_id" unless to_roll
      roll_id = (to_roll.is_a?(Roll) ? to_roll.id : to_roll)

      return basic_dupe!(orig_frame, user_id, roll_id)
    end
    
    def self.remove_dupe_of_frame_from_roll!(frame, roll)
      raise ArgumentError, "must supply Frame" unless frame.is_a? Frame
      raise ArgumentError, "must supply roll or roll_id" unless roll
      roll_id = (roll.is_a?(Roll) ? roll.id : roll)
      
      # Is it overkill / does it hurt performance to check frame_ancestors?
      dupe = Frame.where(
        :roll_id => roll_id, 
        :video_id => frame.video_id, 
        :conversation_id => frame.conversation_id,
        :frame_ancestors => (frame.frame_ancestors << frame.id)).first
      
      dupe.destroy if dupe
    end
    
    def self.backfill_dashboard_entries(user, roll, frame_count=5)
      raise ArgumentError, "must supply a User" unless user.is_a? User
      raise ArgumentError, "must supply a Roll" unless roll.is_a? Roll
      raise ArgumentError, "count must be >= 0" if frame_count < 0
      
      res = []
      roll.frames.sort(:score.desc).limit(frame_count).all.reverse.each do |frame|
        res << create_dashboard_entry(frame, DashboardEntry::ENTRY_TYPE[:new_in_app_frame], user)
      end
      
      return res.flatten
    end
    
    def self.create_dashboard_entry(frame, action, user)
      raise ArgumentError, "must supply a Frame" unless frame.is_a? Frame
      raise ArgumentError, "must supply an action" unless action
      raise ArgumentError, "must supply a User" unless user.is_a? User
      self.create_dashboard_entries(frame, action, [user.id])
    end
    
    private
      
      def self.basic_dupe!(orig_frame, user_id, roll_id)
        # Dupe it
        new_frame = Frame.new
        new_frame.creator_id = orig_frame.creator_id
        new_frame.roll_id = roll_id
        new_frame.video_id = orig_frame.video_id
        
        #copy convo
        new_frame.conversation_id = orig_frame.conversation_id
        
        #copy voting
        new_frame.score = orig_frame.score
        new_frame.upvoters = orig_frame.upvoters.clone

        # Track just my history
        new_frame.frame_ancestors = orig_frame.frame_ancestors.clone
        new_frame.frame_ancestors << orig_frame.id
        # *NOT* adding this as a frame_child of original as that only tracks re-rolls, not dupes

        new_frame.save
        
        return new_frame
      end
      
      def self.basic_re_roll(orig_frame, user_id, roll_id)
        # Set up the basics
        new_frame = Frame.new
        new_frame.creator_id = user_id
        new_frame.roll_id = roll_id
        new_frame.video_id = orig_frame.video_id

        # Create a new conversation
        convo = Conversation.new
        convo.frame = new_frame
        convo.video_id = new_frame.video_id
        convo.public = true
        new_frame.conversation = convo

        # Track the lineage
        new_frame.frame_ancestors = orig_frame.frame_ancestors.clone
        new_frame.frame_ancestors << orig_frame.id
        orig_frame.frame_children << new_frame.id

        new_frame.save

        return new_frame
      end
      
      def self.create_dashboard_entries(frame, action, user_ids)
        entries = []
        user_ids.uniq.each do |user_id|
          dbe = DashboardEntry.new
          dbe.user_id = user_id
          dbe.roll = frame.roll
          dbe.frame = frame
          dbe.action = action
          dbe.save
          entries << dbe
        end
        return entries
      end
      
      def self.ensure_roll_metadata!(roll, frame)
        if roll and frame and vid = frame.video
          # rolls need thumbnails (user.public_roll thumbnail is already set as their avatar)
          roll.update_attribute(:creator_thumbnail_url, vid.thumbnail_url) if roll.creator_thumbnail_url.blank?
          
          # always try and update the rolls :first_frame_thumbnail_url, always.
          roll.update_attribute(:first_frame_thumbnail_url, vid.thumbnail_url)
        end
      end
    
  end
end
    
    
