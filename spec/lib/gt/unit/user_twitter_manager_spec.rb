# encoding: UTF-8

require 'spec_helper'

require 'user_twitter_manager'

# UNIT test
describe GT::UserTwitterManager do

  context "verify_auth" do
    it "should return true if TWT calls returns without throwing exception" do
      APIClients::TwitterClient.stub_chain(:build_for_token_and_secret, :statuses, :home_timeline?).and_return :whatever
      GT::UserTwitterManager.verify_auth(:what, :ever).should == true
    end

    it "should return false if TWT call throws exception" do
      APIClients::TwitterClient.stub_chain(:build_for_token_and_secret, :statuses, :home_timeline?).and_throw Grackle::TwitterError
      GT::UserTwitterManager.verify_auth(:what, :ever).should == false
    end

  end

  context "follow_all_friends_public_rolls" do
    before(:each) do
      @user = Factory.create(:user)

      @user_ids = [111998123958, 2111998123958] #twitter returns these as ints, we need to make them strings
      GT::UserTwitterManager.stub(:friends_ids).and_return(@user_ids)

      @friend1 = Factory.create(:user)
      @friend1.public_roll = Factory.create(:roll, :creator => @friend1)
      @friend1.save
      User.stub(:first).with( :conditions => { 'authentications.provider' => 'twitter', 'authentications.uid' => "111998123958" } ).and_return(@friend1)

      @friend2 = Factory.create(:user)
      @friend2.public_roll = Factory.create(:roll, :creator => @friend2)
      @friend2.save
      User.stub(:first).with( :conditions => { 'authentications.provider' => 'twitter', 'authentications.uid' => "2111998123958" } ).and_return(@friend2)
    end

    it "should follow public rolls of all friends" do
      @friend1.public_roll.should_receive(:add_follower).with(@user).exactly(1).times
      @friend2.public_roll.should_receive(:add_follower).with(@user).exactly(1).times
      GT::UserTwitterManager.follow_all_friends_public_rolls(@user)
    end

    it "should not follow roll if user has unfollowed it" do
      #follow and unfollow public roll of friend1
      @friend1.public_roll.add_follower(@user)
      @friend1.public_roll.remove_follower(@user)

      @friend1.public_roll.should_receive(:add_follower).with(@user).exactly(0).times
      @friend2.public_roll.should_receive(:add_follower).with(@user).exactly(1).times
      GT::UserTwitterManager.follow_all_friends_public_rolls(@user)
    end

    it "should gracefully handle friend ids not known to Shelby" do
      User.stub(:first).and_return(nil)

      #should not error
      GT::UserTwitterManager.follow_all_friends_public_rolls(@user)
    end

  end

  context "unfollow_twitter_faux_user" do
    before(:each) do
      @user = Factory.create(:user)

      @twitter_faux_user = Factory.create(:user, :user_type => User::USER_TYPE[:faux])
      @twitter_faux_user_public_roll = Factory.create(:roll, :creator => @twitter_faux_user)
      @twitter_faux_user.public_roll = @twitter_faux_user_public_roll
      @twitter_faux_user_public_roll.add_follower(@user)

      @twitter_real_user = Factory.create(:user)
      @twitter_real_user_public_roll = Factory.create(:roll, :creator => @twitter_real_user)
      @twitter_real_user.public_roll = @twitter_real_user_public_roll
      @twitter_real_user_public_roll.add_follower(@user)

    end

    it "unfollows the public roll of the twitter user if that user is a faux user" do
      expect(@user.roll_followings).to be_any {|rf| rf.roll_id == @twitter_faux_user.public_roll_id}

      expect {
        @res = GT::UserTwitterManager.unfollow_twitter_faux_user(@user, @twitter_faux_user.authentications.first.uid)
      }.to change(@user.roll_followings,:count).by(-1)

      expect(@user.roll_followings).not_to be_any {|rf| rf.roll_id == @twitter_faux_user.public_roll_id}
      expect(@res).to be_true
    end

    it "does nothing if the twitter user is a real user" do
      expect {
        @res = GT::UserTwitterManager.unfollow_twitter_faux_user(@user, @twitter_real_user.authentications.first.uid)
      }.not_to change(@user.roll_followings,:count)

      expect(@res).to be_false
    end

    it "does not get confused by matching uid from another provider" do
      @twitter_faux_user.authentications.first.provider = 'facebook'
      @twitter_faux_user.save

      expect {
        @res = GT::UserTwitterManager.unfollow_twitter_faux_user(@user, @twitter_faux_user.authentications.first.uid)
      }.not_to change(@user.roll_followings,:count)

      expect(@res).to be_false
    end

    it "does nothing if the twitter uid doesn't exist" do
      expect {
        @res = GT::UserTwitterManager.unfollow_twitter_faux_user(@user, 'baduid')
      }.not_to change(@user.roll_followings,:count)

      expect(@res).to be_false
    end

    it "does nothing if the user isn't following the twitter user in question on Shelby" do
      twitter_faux_user2 = Factory.create(:user, :user_type => User::USER_TYPE[:faux])
      twitter_faux_user2_public_roll = Factory.create(:roll, :creator => twitter_faux_user2)
      twitter_faux_user2.public_roll = twitter_faux_user2_public_roll

      expect {
        @res = GT::UserTwitterManager.unfollow_twitter_faux_user(@user, twitter_faux_user2.authentications.first.uid)
      }.not_to change(@user.roll_followings,:count).by(-1)

      expect(@res).to be_false
    end
  end

end