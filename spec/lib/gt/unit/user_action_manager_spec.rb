require 'spec_helper'
require 'user_action_manager'

# UNIT test
describe GT::UserActionManager do
  before(:all) do
    @user = Factory.create(:user)
    @frame = Factory.create(:frame)
  end
  
  context "view action" do
    it "should allow nil user id" do
      lambda {
        GT::UserActionManager.view!(nil, @frame.id, 0, 1)
      }.should_not raise_error ArgumentError
    end
    
    it "should verify frame exists"  do
      lambda {
        GT::UserActionManager.view!(@user.id, @user.id, 0, 1)
      }.should raise_error ArgumentError
    end
    
    it "should return nil if Frame doesn't have a video_id" do
      GT::UserActionManager.view!(@user.id, @frame.id, 0, 1).should == nil
    end
    
    it "should require start and end times as both nil or both Integers" do
      lambda {
        GT::UserActionManager.view!(@user.id, @frame.id, nil, 1)
      }.should raise_error ArgumentError
      
      lambda {
        GT::UserActionManager.view!(@user.id, @frame.id, 0, nil)
      }.should raise_error ArgumentError
      
      lambda {
        GT::UserActionManager.view!(@user.id, @frame.id, "0", 1)
      }.should raise_error ArgumentError
      
      lambda {
        GT::UserActionManager.view!(@user.id, @frame.id, 0, "1")
      }.should raise_error ArgumentError
      
      #both int okay
      lambda {
        GT::UserActionManager.view!(@user.id, @frame.id, 0, 1)
      }.should_not raise_error ArgumentError
      
      #both nil okay
      lambda {
        GT::UserActionManager.view!(@user.id, @frame.id, nil, nil)
        GT::UserActionManager.view!(@user.id, @frame.id)
      }.should_not raise_error ArgumentError
    end
    
    it "should create correct, persisted UserAction" do
      @frame.video_id = "4f6f66349fb5ba2337000002"
      @frame.save
      
      ua = nil
      lambda {
        ua = GT::UserActionManager.view!(@user.id, @frame.id, 0, 1)
      }.should change{UserAction.count}.by 1
      ua.class.should == UserAction
      ua.persisted?.should == true
      ua.type.should == UserAction::TYPES[:view]
      ua.user_id.should == @user.id
      ua.frame_id.should == @frame.id
      ua.video_id.should == @frame.video_id
      ua.start_s.should == 0
      ua.end_s.should == 1
    end
  end
  
  context "upvote action" do
    it "should require valid user_id (w/o lookign for User itself)" do
      lambda {
        GT::UserActionManager.upvote!("xxx", "4f6f66349fb5ba2337000002")
      }.should raise_error ArgumentError
      
      lambda {
        GT::UserActionManager.upvote!("4f6f66349fb5ba2337000002", "4f6f66349fb5ba2337000002")
      }.should_not raise_error ArgumentError
    end
    
    it "should require valid frame_id (w/o looking for Frame itself)" do
      lambda {
        GT::UserActionManager.upvote!("4f6f66349fb5ba2337000002", "xxx")
      }.should raise_error ArgumentError
      
      lambda {
        GT::UserActionManager.upvote!("4f6f66349fb5ba2337000002", "4f6f66349fb5ba2337000002")
      }.should_not raise_error ArgumentError
    end
    
    it "should create correct, persisted UserAction" do
      ua = nil
      lambda {
        ua = GT::UserActionManager.upvote!("4f6f66349fb5ba2337000002", "4f6f66349fb5ba2337000002")
      }.should change{UserAction.count}.by 1
      ua.class.should == UserAction
      ua.persisted?.should == true
      ua.type.should == UserAction::TYPES[:upvote]
      ua.user_id.to_s.should == "4f6f66349fb5ba2337000002"
      ua.frame_id.to_s.should == "4f6f66349fb5ba2337000002"
    end
  end
  
  context "unupvote action" do
    it "should require valid user_id (w/o lookign for User itself)" do
      lambda {
        GT::UserActionManager.unupvote!("xxx", "4f6f66349fb5ba2337000002")
      }.should raise_error ArgumentError
      
      lambda {
        GT::UserActionManager.unupvote!("4f6f66349fb5ba2337000002", "4f6f66349fb5ba2337000002")
      }.should_not raise_error ArgumentError
    end
    
    it "should require valid frame_id (w/o looking for Frame itself)" do
      lambda {
        GT::UserActionManager.unupvote!("4f6f66349fb5ba2337000002", "xxx")
      }.should raise_error ArgumentError
      
      lambda {
        GT::UserActionManager.unupvote!("4f6f66349fb5ba2337000002", "4f6f66349fb5ba2337000002")
      }.should_not raise_error ArgumentError
    end
    
    it "should create correct, persisted UserAction" do
      ua = nil
      lambda {
        ua = GT::UserActionManager.unupvote!("4f6f66349fb5ba2337000002", "4f6f66349fb5ba2337000002")
      }.should change{UserAction.count}.by 1
      ua.class.should == UserAction
      ua.persisted?.should == true
      ua.type.should == UserAction::TYPES[:unupvote]
      ua.user_id.to_s.should == "4f6f66349fb5ba2337000002"
      ua.frame_id.to_s.should == "4f6f66349fb5ba2337000002"
    end
  end
  
  context "follow action" do
    it "should require valid user_id (w/o lookign for User itself)" do
      lambda {
        GT::UserActionManager.follow_roll!("xxx", "4f6f66349fb5ba2337000002")
      }.should raise_error ArgumentError
      
      lambda {
        GT::UserActionManager.follow_roll!("4f6f66349fb5ba2337000002", "4f6f66349fb5ba2337000002")
      }.should_not raise_error ArgumentError
    end
    
    it "should require valid roll_id (w/o looking for Frame itself)" do
      lambda {
        GT::UserActionManager.follow_roll!("4f6f66349fb5ba2337000002", "xxx")
      }.should raise_error ArgumentError
      
      lambda {
        GT::UserActionManager.follow_roll!("4f6f66349fb5ba2337000002", "4f6f66349fb5ba2337000002")
      }.should_not raise_error ArgumentError
    end
    
    it "should create correct, persisted UserAction" do
      ua = nil
      lambda {
        ua = GT::UserActionManager.follow_roll!("4f6f66349fb5ba2337000002", "4f6f66349fb5ba2337000002")
      }.should change{UserAction.count}.by 1
      ua.class.should == UserAction
      ua.persisted?.should == true
      ua.type.should == UserAction::TYPES[:follow_roll]
      ua.user_id.to_s.should == "4f6f66349fb5ba2337000002"
      ua.roll_id.to_s.should == "4f6f66349fb5ba2337000002"
    end
  end
  
  context "unfollow action" do
    it "should require valid user_id (w/o lookign for User itself)" do
      lambda {
        GT::UserActionManager.unfollow_roll!("xxx", "4f6f66349fb5ba2337000002")
      }.should raise_error ArgumentError
      
      lambda {
        GT::UserActionManager.unfollow_roll!("4f6f66349fb5ba2337000002", "4f6f66349fb5ba2337000002")
      }.should_not raise_error ArgumentError
    end
    
    it "should require valid roll_id (w/o looking for Frame itself)" do
      lambda {
        GT::UserActionManager.unfollow_roll!("4f6f66349fb5ba2337000002", "xxx")
      }.should raise_error ArgumentError
      
      lambda {
        GT::UserActionManager.unfollow_roll!("4f6f66349fb5ba2337000002", "4f6f66349fb5ba2337000002")
      }.should_not raise_error ArgumentError
    end
    
    it "should create correct, persisted UserAction" do
      ua = nil
      lambda {
        ua = GT::UserActionManager.unfollow_roll!("4f6f66349fb5ba2337000002", "4f6f66349fb5ba2337000002")
      }.should change{UserAction.count}.by 1
      ua.class.should == UserAction
      ua.persisted?.should == true
      ua.type.should == UserAction::TYPES[:unfollow_roll]
      ua.user_id.to_s.should == "4f6f66349fb5ba2337000002"
      ua.roll_id.to_s.should == "4f6f66349fb5ba2337000002"
    end
  end
  
  context "watch later action" do
    it "should require valid user_id (w/o lookign for User itself)" do
      lambda {
        GT::UserActionManager.watch_later!("xxx", "4f6f66349fb5ba2337000002")
      }.should raise_error ArgumentError
      
      lambda {
        GT::UserActionManager.watch_later!("4f6f66349fb5ba2337000002", "4f6f66349fb5ba2337000002")
      }.should_not raise_error ArgumentError
    end
    
    it "should require valid frame_id (w/o looking for Frame itself)" do
      lambda {
        GT::UserActionManager.watch_later!("4f6f66349fb5ba2337000002", "xxx")
      }.should raise_error ArgumentError
      
      lambda {
        GT::UserActionManager.watch_later!("4f6f66349fb5ba2337000002", "4f6f66349fb5ba2337000002")
      }.should_not raise_error ArgumentError
    end
    
    it "should create correct, persisted UserAction" do
      ua = nil
      lambda {
        ua = GT::UserActionManager.watch_later!("4f6f66349fb5ba2337000002", "4f6f66349fb5ba2337000002")
      }.should change{UserAction.count}.by 1
      ua.class.should == UserAction
      ua.persisted?.should == true
      ua.type.should == UserAction::TYPES[:watch_later]
      ua.user_id.to_s.should == "4f6f66349fb5ba2337000002"
      ua.frame_id.to_s.should == "4f6f66349fb5ba2337000002"
    end
  end
  
  context "unwatch later action" do
    it "should require valid user_id (w/o lookign for User itself)" do
      lambda {
        GT::UserActionManager.unwatch_later!("xxx", "4f6f66349fb5ba2337000002")
      }.should raise_error ArgumentError
      
      lambda {
        GT::UserActionManager.unwatch_later!("4f6f66349fb5ba2337000002", "4f6f66349fb5ba2337000002")
      }.should_not raise_error ArgumentError
    end
    
    it "should require valid frame_id (w/o looking for Frame itself)" do
      lambda {
        GT::UserActionManager.unwatch_later!("4f6f66349fb5ba2337000002", "xxx")
      }.should raise_error ArgumentError
      
      lambda {
        GT::UserActionManager.unwatch_later!("4f6f66349fb5ba2337000002", "4f6f66349fb5ba2337000002")
      }.should_not raise_error ArgumentError
    end
    
    it "should create correct, persisted UserAction" do
      ua = nil
      lambda {
        ua = GT::UserActionManager.unwatch_later!("4f6f66349fb5ba2337000002", "4f6f66349fb5ba2337000002")
      }.should change{UserAction.count}.by 1
      ua.class.should == UserAction
      ua.persisted?.should == true
      ua.type.should == UserAction::TYPES[:unwatch_later]
      ua.user_id.to_s.should == "4f6f66349fb5ba2337000002"
      ua.frame_id.to_s.should == "4f6f66349fb5ba2337000002"
    end
  end
  
end