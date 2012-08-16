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
  
end