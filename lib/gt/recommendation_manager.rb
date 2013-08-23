# encoding: UTF-8

module GT

  # This manager gets video recommendations of various types from our different recommendation
  # sources
  class RecommendationManager

    # Returns an array of recommended video ids and source frame ids for a user based on the criteria supplied as params
    def self.get_random_video_graph_recs_for_user(user, max_db_entries_to_scan=10, limit=1, min_score=nil)

      dbes = DashboardEntry.where(:user_id => user.id).order(:_id.desc).limit(max_db_entries_to_scan).fields(:video_id, :frame_id).all

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
