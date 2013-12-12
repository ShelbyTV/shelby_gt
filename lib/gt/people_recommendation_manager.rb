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
    # --options--
    #
    # :other_user => User --- the user from whose roll followings the user recommendations will be taken
    def recommend_other_users_followings(other_user)
      raise ArgumentError, "must supply valid User Object" unless other_user.is_a?(User)
      raise ArgumentError, "must supply a different user" unless @user != other_user

      other_user_followed_rolls =
        Roll.where(:_id.in => other_user.roll_followings.map { |rf| rf.roll_id })
            .fields(:roll_type, :creator_id)
            .select do |r|
              # only consider "real public rolls"
              [Roll::TYPES[:special_public_real_user], Roll::TYPES[:special_public_upgraded]].include? r.roll_type
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
      return filtered_ids

    end

  end

end
