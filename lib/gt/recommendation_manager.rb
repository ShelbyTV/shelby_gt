# encoding: UTF-8

module GT

  # This manager gets video recommendations of various types from our different recommendation
  # sources
  class RecommendationManager

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
        recs = self.get_random_video_graph_recs_for_user(user, 10, 1, 100.0, dbes)
        unless recs.empty?
          # wrap the recommended video in a dashboard entry
          rec = recs[0]
          dashboard_entry_options = {:src_frame_id => rec[:src_frame_id]}
          if options[:insert_at_random_location]
            # if requested, set the new dashboard entry's creation time to be just earlier
            # than a randomly selected recent entry, so it will appear just before that entry
            # in the stream
            insert_before_entry = recent_dbes.sample
            dashboard_entry_options[:creation_time] = insert_before_entry.id.generation_time - 1
          end
          res = GT::Framer.create_frame(
            :video_id => rec[:recommended_video_id],
            :dashboard_user_id => user.id,
            :action => DashboardEntry::ENTRY_TYPE[:video_graph_recommendation],
            :dashboard_entry_options => dashboard_entry_options
          )
          if res[:dashboard_entries] and !res[:dashboard_entries].empty?
            # return the new dashboard entry
            return res[:dashboard_entries][0]
          end
        end
      end
    end

    # Returns an array of recommended video ids and source frame ids for a user based on the criteria supplied as params
    # NB: This is a slow thing to be doing - ideally we'd want to run this periodically in the background and store
    # the results somewhere to then be loaded instantaneously when asked for
    def self.get_random_video_graph_recs_for_user(user, max_db_entries_to_scan=10, limit=1, min_score=nil, prefetched_dbes=nil)

      unless prefetched_dbes
        dbes = DashboardEntry.where(:user_id => user.id).order(:_id.desc).limit(max_db_entries_to_scan).fields(:video_id, :frame_id).all
      else
        dbes = prefetched_dbes.slice(0, max_db_entries_to_scan)
      end

      recs = []
      watched_video_ids = []
      watched_videos_loaded = false

      dbes.each do |dbe|
        recs_for_this_video = Video.where( :id => dbe.video_id ).fields(:recs).map{|v| v.recs}.flatten

        if min_score
          recs_for_this_video.select!{|r| r.score >= min_score}
        end

        # remove any videos that the user has already watched
        if recs_for_this_video.length > 0 && user.viewed_roll_id
          # once we know we need them, load the ids of the videos the user has watched - only do this once
          if !watched_videos_loaded
            watched_video_ids = Frame.where(:roll_id => user.viewed_roll_id).fields(:video_id).limit(2000).all.map {|f| f.video_id}.compact
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

  end
end
