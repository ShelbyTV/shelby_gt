# encoding: UTF-8

module GT

  # This manager gets video recommendations of various types from our different recommendation
  # sources
  class RecommendationManager

    # Returns an array of recommended video ids for a user based on the criteria supplied as params
    def self.get_random_video_graph_recs_for_user(user, maxDbEntriesToScan=50, maxVideos=1)
      frame_ids = DashboardEntry.where(:user_id => user.id).limit(maxDbEntriesToScan).fields(:frame_id).map{|dbe| dbe.frame_id}
      video_ids = Frame.where( :id => {:$in => frame_ids}).fields(:video_id).map{|f| f.video_id}
    end

  end
end
