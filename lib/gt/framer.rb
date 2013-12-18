# This is the one and only place where Frames are created.
#
# If the user re-rolls a Frame, that goes through us.
# If Arnold 2, the bookmarklet, or a dev script needs to create a Frame, that goes through us.
#
require 'new_relic/agent/method_tracer'
module GT
  class Framer
    include ::NewRelic::Agent::MethodTracer
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
    # :action => DashboardEntry::ENTRY_TYPE[?] --- OPTIONAL: what action created this frame? Distinguish between social, bookmark
    # :score => Float --- OPTIONAL initial score for ordering the frames in a roll
    # :order => Float --- OPTIONAL manual ordering for genius rolls
    # :genius => Bool --- OPTIONAL indicates if the frame is a genius frame; genius frames don't create conversations
    # :skip_dashboard_entries => Bool -- OPTIONAL set to true if you don't want any dashboard entries created
    # :async_dashboard_entries => Bool -- OPTIONAL set to true if you want dashboard entries created async.
    #                            - N.B. return value will not include :dashboard_entries if this is set to true
    #                            - N.B. it does not make sense to turn this option on if :persist is set to false
    # :frame_type => is this a heavy_weight or light_weight frame type
    # :dashboard_entry_options => Hash -- OPTIONAL if dashboard entries are created, this will be passed as the options parameter
    # :persist => Bool -- OPTIONAL if set to false, the created frames and/or dashboard entries will not be saved to the DB
    #                        - For the moment, non-persistent frames will not support conversations, so :message param will be ignored
    # :return_dbe_models => Bool -- OPTIONAL if set to true, and any dashboard entries are created, they will be returned in the result hash
    # => at [:dashboard_entries], default is false, only makes sense if :skip_dashboard_entries and :async_dashboard_entries are both false
    #
    # --returns--
    #
    # false if message.origin_id already exists in DB's unique index
    # if :return_dbe_models is true, :skip_dashboard_entries and :async_dashbaord_entries are false
    # => { :frame => newly_created_frame, :dashboard_entries => [0 or more DashboardEntries, ...] }
    # if :return_dbe_models is false
    # => { :frame => newly_created_frame }
    #
    def self.create_frame(options)
      creator = options.delete(:creator)
      score = options.delete(:score)
      order = options.delete(:order)
      video = options.delete(:video)
      video_id = options.delete(:video_id)
      genius = options.delete(:genius)
      frame_type = options.delete(:frame_type)
      skip_dashboard_entries = options.delete(:skip_dashboard_entries)
      async_dashboard_entries = options.delete(:async_dashboard_entries)
      return_dbe_models = options.delete(:return_dbe_models)
      dashboard_entry_options = options.delete(:dashboard_entry_options) || {}
      raise ArgumentError, "must include a :video or :video_id" unless video.is_a?(Video) or video_id.is_a?(BSON::ObjectId)
      raise ArgumentError, "must not supply both :video and :video_id" if (video and video_id)
      raise ArgumentError, "must supply an :action" unless DashboardEntry::ENTRY_TYPE.values.include?(action = options.delete(:action)) or skip_dashboard_entries
      roll = options.delete(:roll)
      dashboard_user_id = options.delete(:dashboard_user_id)
      raise ArgumentError, "must include a :roll or :dashboard_user_id" unless roll.is_a?(Roll) or dashboard_user_id.is_a?(BSON::ObjectId)
      message = options.delete(:message)
      raise ArgumentError, ":message must be a Message" if message and !message.is_a?(Message)
      persist = options.delete(:persist)
      persist = true if persist.nil?
      raise ArgumentError, ":persist must be true if :async_dashboard_entries is true" if async_dashboard_entries && !persist
      dashboard_entry_options[:persist] = persist

      # Try to safely create conversation
      if genius || !persist
        convo = nil
      else
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
      end

      res = { :frame => nil }

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
      f.frame_type = frame_type if frame_type

      f.save if persist

      #track the original frame in the convo
      if convo
        convo.update_attribute(:frame_id, f.id)
      end

      res[:frame] = f

      unless skip_dashboard_entries
        # DashboardEntry
        # We need dashboard entries for the roll's followers or the given dashboard_user_id
        user_ids = []
        user_ids << dashboard_user_id if dashboard_user_id
        user_ids += roll.following_users_ids if (roll && persist)

        # Run dashboard entry creation async. if asked too
        if async_dashboard_entries
          create_dashboard_entries_async([f], action, user_ids, dashboard_entry_options)
        else
          if return_dbe_models
            dashboard_entry_options[:return_dbe_models] = true
            res[:dashboard_entries] = create_dashboard_entries([f], action, user_ids, dashboard_entry_options)
          else
            create_dashboard_entries([f], action, user_ids, dashboard_entry_options)
          end
        end
      end

      # Roll - set its thumbnail if missing, update content_updated_at
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
    # { :frame => newly_created_frame }
    #
    def self.re_roll(orig_frame, for_user, to_roll, options={})
      raise ArgumentError, "must supply user or user_id" unless for_user
      user_id = (for_user.is_a?(User) ? for_user.id : for_user)

      raise ArgumentError, "must supply roll" unless to_roll && to_roll.is_a?(Roll)
      roll_id = to_roll.id

      res = { :frame => nil }

      res[:frame] = basic_re_roll(orig_frame, user_id, roll_id, options)

      unless options[:skip_dashboard_entries]
        #create dashboard entries for all roll followers *except* the user who just re-rolled
        create_dashboard_entries_async([res[:frame]], DashboardEntry::ENTRY_TYPE[:re_roll], to_roll.following_users_ids - [user_id])
        # create dbe for iOS Push and Notification Center notifications, asynchronously
        dbe_type = (options[:frame_type] == Frame::FRAME_TYPE[:light_weight]) ? DashboardEntry::ENTRY_TYPE[:like_notification] :  DashboardEntry::ENTRY_TYPE[:share_notification]
        create_dashboard_entries_async([orig_frame], dbe_type, [orig_frame.creator_id], {:actor_id => user_id})
      end

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

    def self.backfill_dashboard_entries(user, roll, frame_count=5, options={})
      raise ArgumentError, "must supply a User" unless user.is_a? User
      raise ArgumentError, "must supply a Roll" unless roll.is_a? Roll
      raise ArgumentError, "count must be >= 0" if frame_count < 0

      dbe_options = {:backdate => true}
      frames_to_backfill = roll.frames.sort(:score.desc).limit(frame_count).all.reverse

      async_dashboard_entries = options.delete(:async_dashboard_entries)

      if async_dashboard_entries
        create_dashboard_entries_async(frames_to_backfill, DashboardEntry::ENTRY_TYPE[:new_in_app_frame], [user.id], dbe_options)
      else
        create_dashboard_entries(frames_to_backfill, DashboardEntry::ENTRY_TYPE[:new_in_app_frame], [user.id], dbe_options)
      end

      return nil
    end

    def self.create_dashboard_entry(frame, action, user, options={})
      raise ArgumentError, "must supply a Frame, an Actor, or both" unless frame.is_a?(Frame) || options[:actor_id]
      raise ArgumentError, "must supply an action" unless action
      raise ArgumentError, "must supply a User" unless user.is_a? User

      defaults = {
        :persist => true,
      }

      options = defaults.merge(options)

      dbe = self.initialize_dashboard_entry(frame, action, user.id, options)
      dbe_model = DashboardEntry.from_mongo(dbe)
      dbe_model.save if options[:persist]
      return [dbe_model]
    end

    def self.create_dashboard_entries(frames, action, user_ids, options={})
      raise ArgumentError, "must supply a Frame, an Actor, or both" if frames.include?(nil) && !options[:actor_id]
      defaults = {
        :persist => true,
        :return_dbe_models => false
      }

      options = defaults.merge(options)

      persist = options.delete(:persist)
      return_dbe_models = options.delete(:return_dbe_models)

      dbes = [] # used to collect hashes to pass directly to the Ruby driver if persisting
      dbe_models = [] # used to collect MongoMapper DashboardEntry models if returning anything
      frames.each do |frame|
        user_ids.uniq.each do |user_id|
          # have to declare these variables outside the scope of the tracing blocks
          dbe = nil
          dbe_model = nil
          self.class.trace_execution_scoped(['Custom/create_dashboard_entries/create_dbe_model']) do
            # we start with a hash representing the DashboardEntry
            dbe = self.initialize_dashboard_entry(frame, action, user_id, options)
            if return_dbe_models
              # if we're going to be returning DashboardEntry models, convert the hash into a model
              dbe_model = DashboardEntry.from_mongo(dbe)
            end
          end
          self.class.trace_execution_scoped(['Custom/create_dashboard_entries/append_dbes_to_array']) do
            if return_dbe_models
              # the MongoMapper models are only used if return_dbe_models == true
              dbe_models << dbe_model if return_dbe_models
            else
              # from this point on, the hashes are only used for persistence,
              # so only perform more work on them if persist == true
              if persist
                # map the keys to their abbreviations before using the Ruby Driver directly to insert the documents
                dbe.keys.each {|k, v| dbe[DashboardEntry.abbr_for_key_name(k)] = dbe.delete(k)}
                dbes << dbe
              end
            end
          end
        end
      end

      # if persisting, do it all in one operation so that it only checks out one socket
      if persist
          if return_dbe_models
            if !dbe_models.empty?
              # if we've created MongoMapper models, convert them to hashes and insert
              DashboardEntry.collection.insert(dbe_models.map {|dbe| dbe.to_mongo })
            end
          elsif !dbes.empty?
            # if we have hashes already, just pass them through to insert
            DashboardEntry.collection.insert(dbes)
          end
      end

      return return_dbe_models ? dbe_models : nil
    end

    class << self
      include ::NewRelic::Agent::MethodTracer
      add_method_tracer :create_dashboard_entries, 'Custom/Framer/create_dashboard_entries'
    end

    def self.create_dashboard_entries_async(frames, action, user_ids, options={})
      # no point queueing up the job if no user_ids are passed in
      return if user_ids.empty?

      defaults = {
        :persist => true,
      }

      options = defaults.merge(options)

      Resque.enqueue(DashboardEntryCreator, frames.map{ |f| f && f.id }, action, user_ids, options)
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

      def self.basic_re_roll(orig_frame, user_id, roll_id, options={})
        # Set up the basics
        new_frame = Frame.new
        new_frame.creator_id = user_id
        new_frame.roll_id = roll_id
        new_frame.video_id = orig_frame.video_id
        new_frame.frame_type = options[:frame_type] if options[:frame_type]

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

      # create a hash containing the attributes for a new DashboardEntry
      def self.initialize_dashboard_entry(frame, action, user_id, options={})
        dbe = {}
        if options[:creation_time]
          dbe[:_id] = BSON::ObjectId.from_time(options[:creation_time], :unique => true)
        elsif options[:backdate]
          dbe[:_id] = BSON::ObjectId.from_time(frame.created_at, :unique => true)
        end

        dbe[:user_id] = user_id
        dbe[:roll_id] = frame && frame.roll_id
        dbe[:frame_id] = frame && frame.id
        dbe[:src_frame_id] = options[:src_frame_id]
        dbe[:src_video_id] = options[:src_video_id]
        dbe[:friend_sharers_array] = options[:friend_sharers_array] if options[:friend_sharers_array]
        dbe[:friend_viewers_array] = options[:friend_viewers_array] if options[:friend_viewers_array]
        dbe[:friend_likers_array] = options[:friend_likers_array] if options[:friend_likers_array]
        dbe[:friend_rollers_array] = options[:friend_rollers_array] if options[:friend_rollers_array]
        dbe[:friend_complete_viewers_array] = options[:friend_complete_viewers_array] if options[:friend_complete_viewers_array]
        dbe[:video_id] = frame && frame.video_id

        actor_id = options.delete(:actor_id)
        if actor_id
          actor_id = BSON::ObjectId.from_string(actor_id) if !actor_id.is_a?(BSON::ObjectId)
        else
          actor_id = frame.creator_id
        end
        dbe[:actor_id] = actor_id

        dbe[:action] = action

        return dbe
      end

      def self.ensure_roll_metadata!(roll, frame)
        if roll and frame
            # some useful denormalized metadata
            roll.update_attribute(:content_updated_at, Time.now)

            if vid = frame.video
            # rolls need thumbnails (user.public_roll thumbnail is already set as their avatar)
            roll.update_attribute(:creator_thumbnail_url, vid.thumbnail_url) if roll.creator_thumbnail_url.blank?

            # always try and update the rolls :first_frame_thumbnail_url, always.
            roll.update_attribute(:first_frame_thumbnail_url, vid.thumbnail_url)
          end
        end
      end

  end
end


