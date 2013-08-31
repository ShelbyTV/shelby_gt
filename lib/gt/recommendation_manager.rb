# encoding: UTF-8

module GT

  # This manager gets video recommendations of various types from our different recommendation
  # sources
  class RecommendationManager

    # checks num_recents_to_check dbentries to see if they are recommendations
    # if so, returns nil
    # if not, returns a persisted dbe recommendation
    def self.if_no_recent_recs_generate_rec(user, num_recents_to_check=5)

      # we're looking ahead to using these dbentries to look for some video graph recommendations,
      # so get as many we need for that and to check for recent recommendations
      max_db_entries_to_scan_for_videograph = 10
      num_dbes_to_fetch = [num_recents_to_check, max_db_entries_to_scan_for_videograph].max

      dbes = DashboardEntry.where(:user_id => user.id).order(:_id.desc).limit(num_dbes_to_fetch).fields(:video_id, :frame_id, :action)

      unless dbes.slice(0, num_recents_to_check).any? { |dbe| dbe.is_recommendation? }
        # if we don't find any recommendations within the recency limit, grab one
        recs = self.get_random_video_graph_recs_for_user(user, 10, 1, 100.0, dbes)
        unless recs.empty?

        else
          nil
        end
      else
        nil
      end
    end

    # Returns an array of recommended video ids and source frame ids for a user based on the criteria supplied as params
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

      return recs
    end

  end
end
