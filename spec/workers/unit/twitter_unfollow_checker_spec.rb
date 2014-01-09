require 'spec_helper'

# UNIT test
describe TwitterUnfollowChecker do
  before(:each) do
    @unfollower = Factory.create(:user)
    @unfollowee_uid = 'uid'
  end

  it "calls unfollow_twitter_faux_user with correct parameters" do
    User.stub(:first).and_return(@unfollower)
    GT::UserTwitterManager.should_receive(:unfollow_twitter_faux_user).with(@unfollower, @unfollowee_uid)

    TwitterUnfollowChecker.perform(@unfollower.authentications.first.uid, @unfollowee_uid)
  end

  it "does nothing if the unfollower is not found" do
    User.stub(:first)
    GT::UserTwitterManager.should_not_receive(:unfollow_twitter_faux_user)

    TwitterUnfollowChecker.perform(@unfollower.authentications.first.uid, @unfollowee_uid)
  end

end