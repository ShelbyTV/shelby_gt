# Utility methods to retrieve stats of interest about video recommendations and the
# entertainment graph

module Dev
  class VideoGraphStats

    # for a user or array of users, return the number of videos at the head of their
    # prioritized dashboard that are not at the head of their regular dashboard
    def self.prioritized_videos_unique_results(user, head_size=50)
      user = [user] unless user.is_a? Enumerable

      user.map do |u|
        dashboard_video_ids = DashboardEntry.where(:user_id => BSON.ObjectId(u)).limit(head_size).find_each.map{|dbe| dbe.frame.video.id.to_s}.uniq
        prioritized_dashboard_video_ids = PrioritizedDashboardEntry.where(:user_id => BSON.ObjectId(u)).limit(head_size).find_each.map{|dbe| dbe.frame.video.id.to_s}.uniq
        prioritized_dashboard_video_ids - dashboard_video_ids
      end
    end

  end
end
