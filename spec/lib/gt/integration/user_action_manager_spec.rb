require 'spec_helper'
require 'user_action_manager'

# INTEGRATION test
describe GT::UserActionManager do
  
  context "frame" do
    before(:each) do
      @user = Factory.create(:user)
      @user.upvoted_roll = Factory.create(:roll, :creator => @user)
      @user.save
      @frame = Factory.create(:frame)
    end
    
    it "should not add a UserAction for vote on frame.upvote (that's for the controllers)" do
      lambda {
        @frame.upvote!(@user)
      }.should_not change { UserAction.count }
    end
  end
  
  context "roll" do
    before(:each) do
      @user = Factory.create(:user)
      @roll = Factory.build(:roll)
      @roll.creator = Factory.create(:user)
      @roll.save
    end
    
    it "should add a UserAction for follow on roll.add_follower" do
      lambda {
        @roll.add_follower(@user)
      }.should change { UserAction.count } .by 1
    end
    
    it "should not add a UserAction when the user alreadys follows the roll" do
      @roll.add_follower(@user)
      lambda {
        @roll.add_follower(@user)
      }.should_not change { UserAction.count }
    end
    
    it "should add a UserAction for un-follow on roll.un_follow" do
      @roll.add_follower(@user)
      lambda {
        @roll.remove_follower(@user)
      }.should change { UserAction.count } .by 1
    end
    
    it "should not add a UserAction for un-follow on roll.un_follow unless user follows roll" do
      lambda {
        @roll.remove_follower(@user)
      }.should_not change { UserAction.count }
    end
    
  end
end