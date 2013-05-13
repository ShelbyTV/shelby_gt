# Utility methods to retrieve stats of interest about video recommendations and the
# entertainment graph

module Dev
  class VideoGraphStats

    # for a user or array of users, return the number of videos at the head of their
    # prioritized dashboard that are not at the head of their regular dashboard
    def self.prioritized_videos_unique_results(user, head_size=50)
      user = [user] unless user.is_a? Enumerable

      user.map do |u|
        if u.is_a?(BSON::ObjectId) || BSON::ObjectId.legal?(u)
          user_object = User.find(u)
        else
          user_object = User.find_by_nickname(u.to_s)
        end

        if user_object
          dashboard_video_ids = DashboardEntry.where(:user_id => user_object.id).limit(head_size).find_each.map{|dbe| dbe.frame.video.id.to_s}.uniq
          prioritized_dashboard_video_ids = PrioritizedDashboardEntry.where(:user_id => user_object.id).limit(head_size).find_each.map{|dbe| dbe.frame.video.id.to_s}.uniq
          {
            :user => {
              :id => user_object.id,
              :nickname => user_object.nickname
            },
            :dashboard_videos => dashboard_video_ids.count,
            :prioritized_videos => prioritized_dashboard_video_ids.count,
            :complement_videos => (prioritized_dashboard_video_ids - dashboard_video_ids).count
          }
        else
          {
            :user => "not found"
          }
        end
      end
    end

  end
end
