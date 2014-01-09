class TwitterUnfollowChecker
  @queue = :twitter_unfollow

  def self.perform(unfollower_uid, unfollowee_uid)
    if unfollower = User.first('authentications.uid' => unfollower_uid, 'authentications.provider' => 'twitter')
      GT::UserTwitterManager.unfollow_twitter_faux_user(unfollower, unfollowee_uid)
    end
  end

end