require 'spec_helper'

# INTEGRATION test
describe TwitterUnfollowChecker do
  before(:each) do
    @user = Factory.create(:user)

    @twitter_faux_user = Factory.create(:user, :user_type => User::USER_TYPE[:faux])
    @twitter_faux_user_public_roll = Factory.create(:roll, :creator => @twitter_faux_user)
    @twitter_faux_user.public_roll = @twitter_faux_user_public_roll
    @twitter_faux_user_public_roll.add_follower(@user)
  end

  it "unfollows the public roll of the twitter user if that user is a faux user" do
    expect(@user.roll_followings).to be_any {|rf| rf.roll_id == @twitter_faux_user.public_roll_id}

    expect {
      TwitterUnfollowChecker.perform(@user.authentications.first.uid, @twitter_faux_user.authentications.first.uid)
    }.to change(@user.roll_followings,:count).by(-1)

    expect(@user.roll_followings).not_to be_any {|rf| rf.roll_id == @twitter_faux_user.public_roll_id}
  end

end