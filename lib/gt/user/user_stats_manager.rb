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

      Frame.where(:roll_id => u.public_roll_id).limit(num_frames).map do |f|
        OpenStruct.new({:frame => f})
      end
    end

    # Return the number of frames the user has rolled to their personal roll
    # since a specified time (inclusive)
    def self.get_frames_rolled_since(u, time)
      raise ArgumentError, "must supply user" unless u and u.is_a?(User)
      raise ArgumentError, "must supply time" unless time and time.acts_like?(:time)

      # convert the time to a shelby score, as that is what frames are indexed by
      time_score = (time.to_f - Frame::SHELBY_EPOCH.to_f) / Frame::TIME_DIVISOR
      # count all the frames on the user's personal roll with that score or higher
      Frame.where(:roll_id => u.public_roll_id, :score => { :$gte => time_score }).count
    end

  end
end
