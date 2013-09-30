# encoding: UTF-8
require 'mortar_harvester'

module GT

  # This manager gets video recommendations of various types from our different recommendation
  # sources.  Most of the operations need context around a specific user to find valid recommendations,
  # so they require instatiating an instance of the RecommendationManager class with a user passed in
  # as a parameter.  Other utility methods that don't need stored state are defined as class methods.
  class RecommendationManager

    # BEGIN CLASS METHODS

    # checks options[:num_recents_to_check] (default 5) dbentries to see if they are recommendations
    # if so, returns nil
    # if not, returns a new, persisted dbe recommendation
    #
    # --options--
    #
    # :num_recents_to_check => Integer --- if there is already a recommendation within this many stream entries,
    #   this function will not insert a new one (default 5)
    # :insert_at_random_location => Bool --- set to false to insert the new recommendation as the most recent
    #   in the stream, set to true to insert just after a randomly selected entry within the num_recents_to_check range
    def self.if_no_recent_recs_generate_rec(user, options={})

      defaults = {
        :num_recents_to_check => 5,
        :insert_at_random_location => false
      }

      options = defaults.merge(options)

      # we're looking ahead to using these dbentries to look for some video graph recommendations,
      # so get as many we need for that and to check for recent recommendations
      max_db_entries_to_scan_for_videograph = 10
      num_dbes_to_fetch = [options[:num_recents_to_check], max_db_entries_to_scan_for_videograph].max

      dbes = DashboardEntry.where(:user_id => user.id).order(:_id.desc).limit(num_dbes_to_fetch).fields(:video_id, :frame_id, :action).all
      recent_dbes = dbes.first(options[:num_recents_to_check])

      unless recent_dbes.any? { |dbe| dbe.is_recommendation? }
        # if we don't find any recommendations within the recency limit, generate a new recommendation
        rec_manager = GT::RecommendationManager.new(user)
        recs = rec_manager.get_video_graph_recs_for_user(10, 1, 100.0, dbes)
        unless recs.empty?
          # wrap the recommended video in a dashboard entry
          rec = recs[0]
          creation_options = {:src_id => rec[:src_frame_id]}
          if options[:insert_at_random_location]
            # if requested, set the new dashboard entry's creation time to be just earlier
            # than a randomly selected recent entry, so it will appear just before that entry
            # in the stream
            insert_before_entry = recent_dbes.sample
            creation_options[:dashboard_entry_options] = {}
            creation_options[:dashboard_entry_options][:creation_time] = insert_before_entry.id.generation_time - 1
          end

          res = self.create_recommendation_dbentry(user,
            rec[:recommended_video_id],
            DashboardEntry::ENTRY_TYPE[:video_graph_recommendation],
            creation_options
          )
          return res && res[:dashboard_entry]
        end
      end
    end

    # Returns:
    #   a Framer result of the following form:
    #     {:dashboard_entry => the_new_dashboard_entry, :frame => the_new_dashboard_entrys_frame}
    #   or, nil if the Framer fails
    #
    # --options--
    #
    # :persist => Bool --- OPTIONAL whether the newly created dbe and its frame should be persisted to the database or not
    #   defaults to true
    # :src_id => BSON::ObjectId --- OPTIONAL the id of the source object for the recommendation
    #   should be the src frame for a dbe of type DashboardEntry::ENTRY_TYPE[:video_graph_recommendation
    #   should be the reason video for a dbe of type DashboardEntry::ENTRY_TYPE[:mortar_recommendation]
    #   should be the frame from the source channel for a dbe of type Dashboard Entry::ENTRY_TYPE[:channel_recommendation]
    # :dashboard_entry_options => Hash --- OPTIONAL additional options to be pased to the Framer when creating dashboard entries

    def self.create_recommendation_dbentry(user, video_id, dbe_action, options={})

      defaults = {
        :persist => true,
        :dashboard_entry_options => {}
      }

      options = defaults.merge(options)

      if dbe_action != DashboardEntry::ENTRY_TYPE[:channel_recommendation]
        framer_options = {
          :video_id => video_id,
          :dashboard_user_id => user.id,
          :action => dbe_action,
          :persist => options[:persist]
        }

        case dbe_action
        when DashboardEntry::ENTRY_TYPE[:video_graph_recommendation]
          framer_options[:dashboard_entry_options] = {:src_frame_id => options[:src_id]}
        when DashboardEntry::ENTRY_TYPE[:mortar_recommendation]
          framer_options[:dashboard_entry_options] = {:src_video_id => options[:src_id]}
        else
          framer_options[:dashboard_entry_options] = {}
        end

        framer_options[:dashboard_entry_options].merge!(options[:dashboard_entry_options])

        res = GT::Framer.create_frame(framer_options)
        if res && res[:dashboard_entries] && !res[:dashboard_entries].empty? && res[:frame]
          return {:dashboard_entry => res[:dashboard_entries].first, :frame => res[:frame]}
        end
      else
        frame = Frame.find(options[:src_id])
        res = GT::Framer.create_dashboard_entry(frame, dbe_action, user, {}, options[:persist])
        if res && !res.empty?
          return {:dashboard_entry => res[0], :frame => res[0].frame}
        end
      end
    end

    # END CLASS METHODS

    # BEGIN INSTANCE METHODS

    def initialize(user)
      raise ArgumentError, "must supply valid User Object" unless user.is_a?(User)

      @user = user
      @watched_videos_loaded = false
    end

    # Returns an array of recommended video ids and source frame ids for a user based on the criteria supplied as params
    # NB: This is a slow thing to be doing - ideally we'd want to run this periodically in the background and store
    # the results somewhere to then be loaded instantaneously when asked for
    def get_video_graph_recs_for_user(max_db_entries_to_scan=10, limit=1, min_score=nil, prefetched_dbes=nil)

      unless prefetched_dbes
        dbes = DashboardEntry.where(:user_id => @user.id).order(:_id.desc).limit(max_db_entries_to_scan).fields(:video_id, :frame_id).all
      else
        dbes = prefetched_dbes.slice(0, max_db_entries_to_scan)
      end

      recs = []
      watched_video_ids = []
      watched_videos_loaded = false

      dbes.each do |dbe|
        # don't consider recommendation entries themselves as they don't respresent shares and therefore
        # won't have as much context for explaining the recommendation
        next if dbe.is_recommendation?

        recs_for_this_video = Video.where( :id => dbe.video_id ).fields(:recs).map{|v| v.recs}.flatten

        if min_score
          recs_for_this_video.select!{|r| r.score >= min_score}
        end

        # remove any videos that the user has already watched
        if recs_for_this_video.length > 0 && @user.viewed_roll_id
          # once we know we need them, load the ids of the videos the user has watched - only do this once
          if !watched_videos_loaded
            watched_video_ids = Frame.where(:roll_id => @user.viewed_roll_id).fields(:video_id).limit(2000).all.map {|f| f.video_id}.compact.uniq
            watched_videos_loaded = true
          end

          recs_for_this_video.reject!{|rec| watched_video_ids.include? rec.recommended_video_id}
        end

        recs_for_this_video.each do |rec|
          recs << { :recommended_video_id => rec.recommended_video_id, :src_frame_id => dbe.frame_id}
        end
      end

      # we want to end up with different recs each time, so shuffle the array after we've reduced it to
      # recs with a certain minimum score
      recs.shuffle!

      if limit
        recs.slice!(limit..-1)
      end

      # THE SLOWEST PART?: we want to only include videos that are still available at their provider,
      # but we may be calling out to provider APIs for each video here if we don't have the video info recently updated
      recs.select! do |rec|
        vid = Video.find(rec[:recommended_video_id])
        if vid
          GT::VideoManager.update_video_info(vid)
          vid.available
        end
      end

      return recs
    end

    # Returns an array of recommended video ids and source video ids for a user from our Mortar recommendation engine
    def get_mortar_recs_for_user(limit=1)
      raise ArgumentError, "must supply a limit > 0" unless limit.respond_to?(:to_i) && ((limit = limit.to_i) > 0)

      # get more recs than the caller asked for because some of them might be eliminated and we want to
      # have the chance to still recommend something
      recs = GT::MortarHarvester.get_recs_for_user(@user, limit + 49)
      if recs && recs.length > 0
        recs = filter_recs(recs, {:limit => limit, :recommended_video_key => "item_id"})
        recs.map! do |rec|
          {
            :recommended_video_id => BSON::ObjectId.from_string(rec["item_id"]),
            :src_id => BSON::ObjectId.from_string(rec["reason_id"]),
            :action => DashboardEntry::ENTRY_TYPE[:mortar_recommendation]
          }
        end
      else
        []
      end
    end

    # Returns an array of recommended video ids for a user from another user's channel/dashboard
    def get_channel_recs_for_user(channel_user_id, limit=1)
      unless channel_user_id.is_a?(BSON::ObjectId)
        channel_user_id_string = channel_user_id.to_s
        if BSON::ObjectId.legal?(channel_user_id_string)
          channel_user_id = BSON::ObjectId.from_string(channel_user_id_string)
        else
          raise ArgumentError, "must supply a valid channel user id"
        end
      end
      raise ArgumentError, "must supply a limit > 0" unless limit.respond_to?(:to_i) && ((limit = limit.to_i) > 0)

      # get more recs than the caller asked for because some of them might be eliminated and we want to
      # have the chance to still recommend something
      recs = DashboardEntry.where(:user_id => channel_user_id).order(:_id.desc).limit(limit + 49).fields(:video_id, :frame_id).all
      recs = filter_recs(recs, {:limit => limit, :recommended_video_key => "video_id"}) { |rec| rec.actor_id != @user.id }
      recs.map! do |rec|
        {
          :recommended_video_id => rec.video_id,
          :src_id => rec.frame_id,
          :action => DashboardEntry::ENTRY_TYPE[:channel_recommendation]
        }
      end

      return recs
    end

  private

    # Return the passed in array of recs with recs removed that have already been watched by the user
    # or are no longer available at the provider
    #
    # --params--
    #
    # recs => Array -- each entry in the array is a hash where one of its keys holds the id of a video to recommend
    #   by default, we'll look for that video id at [:recommended_video_id], unless options[:recommended_video_key]
    #   specifies otherwise (see below
    #
    # block => Block --- OPTIONAL Call with a block that takes a recommendation as the parameter and returns true or false
    #   that condition will be tested on each recommendation for prequalification - return false and the rec will be filtered out;
    #   return true and filtering will move on to checking if the rec has been watched and whether it is available
    #
    # --options--
    #
    # :limit => Integer --- OPTIONAL if an integer greater than zero is passed, will return an array of
    #   recs of length limit as soon as that many are found
    # :recommended_video_key => String or Symbol --- OPTIONAL the key on the hash
    def filter_recs(recs, options={}, &block)

      defaults = {
        :limit => nil,
        :recommended_video_key => :recommended_video_id
      }

      options = defaults.merge(options)

      limit = options.delete(:limit)

      raise ArgumentError, "must supply a limit > 0 or nil" unless limit.nil? || (limit.respond_to?(:to_i) && ((limit = limit.to_i) > 0))

      # we're only going to look up the watched videos once per instance of the class
      # by the time more videos have been watched, we'll probably be creating a new instance
      if !@watched_videos_loaded
        @watched_video_ids = @user.viewed_roll_id ? Frame.where(:roll_id => @user.viewed_roll_id).fields(:video_id).limit(2000).all.map {|f| f.video_id.to_s}.compact.uniq : []
        @watched_videos_loaded = true
      end
      valid_recommendations = []

      # process the recs and remove ones that we don't want to show the user because they
      # are not available or because the user has already watched them
      recs.each do |rec|
        rec_prequalified = true
        # rec can optionally be filtered based on a block before going to the default tests
        if block_given?
          rec_prequalified = yield rec
        end
        if rec_prequalified
          # check if the user has already watched the video
          if !@watched_video_ids.include? rec[options[:recommended_video_key]].to_s
            # check if the video is still available at the provider
            vid = Video.find(rec[options[:recommended_video_key]])
            if vid
              # if we think the video is available, re-check the provider to
              # make sure it is
              # OPTIMIZATION: if we previously thought the video was unavailable,
              # we won't check if it's become available again;we need a perpetually
              # running Video Doctor to take care of that or we need a more efficient
              # idea for how to deal with it here
              if vid.available
                GT::VideoManager.update_video_info(vid)
                valid_recommendations << rec if vid.available
                # if there's a limited number of recommendations that we need and we've hit it, quit
                break if valid_recommendations.count == limit
              end
            end
          end
        end
      end

      return valid_recommendations

    end

    # END INSTANCE METHODS

  end
end
