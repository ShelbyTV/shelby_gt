# encoding: UTF-8

module GT

  # This manager gets recommendations for a Shelby user of other users they should be interested in.
  class PeopleRecommendationManager

    def initialize(user, options={})
      raise ArgumentError, "must supply valid User Object" unless user.is_a?(User)

      @user = user
    end

    # Returns an array of recommended user ids from another user's roll followings
    # Will only return users whom the recommendee is not already following
    # NB: This is a relatively slow thing to be doing - ideally we'd want to run this periodically in the background and store
    # the results somewhere to then be loaded instantaneously when asked for
    #
    # --parameters--
    # :other_user => User --- the user from whose roll followings the user recommendations will be taken
    #
    # ---options----
    # :limit => Integer --- OPTIONAL the maximum number of recommended user ids to return
    # :shuffle => Boolean --- OPTIONAL whether or not to shuffle the recommended users before returning
    # :min_frames => Integer --- OPTIONAL if specified, only consider followed rolls that have at least this many frames
    # => set to nil to disable this check
    def recommend_other_users_followings(other_user, options={})
      raise ArgumentError, "must supply valid User Object" unless other_user.is_a?(User)
      raise ArgumentError, "must supply a different user" unless @user != other_user

      defaults = {
        :limit => nil,
        :shuffle => false,
        :min_frames => Settings::Recommendations.people[:min_followed_roll_frames]
      }

      options = defaults.merge(options)
      limit = options.delete(:limit)
      shuffle = options.delete(:shuffle)
      min_frames = options.delete(:min_frames)

      other_user_followed_rolls =
        Roll.where(:_id.in => other_user.roll_followings.map { |rf| rf.roll_id })
            .fields(:roll_type, :creator_id, :frame_count)
            .select do |r|
              # only consider "real public rolls"
              [Roll::TYPES[:special_public_real_user], Roll::TYPES[:special_public_upgraded]].include?(r.roll_type) &&
              # if specified, only consider rolls with a certain minimum number of frames
              (!min_frames || r.frame_count >= min_frames)
            end
      other_user_followed_user_ids = other_user_followed_rolls.map {|r| r.creator_id }
      # no reason to recommend the user we already know about that we're basing the recommendations on
      other_user_followed_user_ids.delete(other_user.id)

      this_user_followed_rolls = Roll.where(:_id.in => @user.roll_followings.map { |rf| rf.roll_id }).fields(:creator_id)
      this_user_followed_user_ids = this_user_followed_rolls.map {|r| r.creator_id }

      # select users who the other user follows but the recommendee does not
      user_ids_to_recommend = other_user_followed_user_ids - this_user_followed_user_ids
      filtered_ids = []
      User.fields(:user_type).find(user_ids_to_recommend).each do |u|
        # only return real or converted users
        filtered_ids << u.id if u.user_type == User::USER_TYPE[:real] || u.user_type == User::USER_TYPE[:converted]
      end

      if shuffle
        if limit
          return filtered_ids.sample(limit)
        else
          return filtered_ids.shuffle
        end
      else
        if limit
          return filtered_ids.first(limit)
        else
          return filtered_ids
        end
      end

    end

  end

end
