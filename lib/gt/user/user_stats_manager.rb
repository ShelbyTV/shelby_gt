# encoding: UTF-8

# Looks up and returns user stats.
#
module GT
  class UserStatsManager

    # Return stats for the most recent n frames on a user's personal roll
    # The data returned will be an array with an entry for each frame
    def self.get_dot_tv_stats_for_recent_frames(u, num_frames)
      raise ArgumentError, "must supply user" unless u and u.is_a?(User)
      raise ArgumentError, "must supply num_frames" unless num_frames

      Frame.fields(:roll_id, :view_count, :video, :like_count).where(:roll_id => u.public_roll_id).limit(3).map do |f|
        {
          :view_count => f.view_count,
          :video_total_view_count => f.video ? f.video.view_count : 0,
          :like_count => f.like_count
        }
      end
    end

  end
end
