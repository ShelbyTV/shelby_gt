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

      Frame.where(:roll_id => u.public_roll_id).limit(3).map do |f|
        OpenStruct.new({:frame => f})
      end
    end

  end
end
