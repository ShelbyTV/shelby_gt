# encoding: UTF-8

module GT

  # This manager gets video recommendations of various types from our different recommendation
  # sources
  class RecommendationManager

    # Returns an array of recommended video ids for a user based on the criteria supplied as params
    def self.get_random_video_graph_recs_for_user(user, max_db_entries_to_scan=10, limit=1, min_score=nil)
      video_ids = DashboardEntry.where(:user_id => user.id).order(:_id.desc).limit(max_db_entries_to_scan).fields(:video_id).map{|dbe| dbe.video_id}
      recs = Video.where( :id => {:$in => video_ids}).fields(:recs).map{|v| v.recs}.flatten

      if min_score
        recs.select!{|r| r.score >= min_score}
      end

      # we want to end up with different recs each time, so shuffle the array after we've reduced it to
      # recs with a certain minimum score
      recs.shuffle!

      if limit
        recs.slice!(limit..-1)
      end

      return recs.map{|r| r.recommended_video_id }
    end

  end
end
