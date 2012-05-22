require 'spec_helper'

#Functional: hit the database, treat model as black box
describe Roll do
  before(:each) do
    @roll = Factory.create(:roll, :creator => Factory.create(:user))
    @user = Factory.create(:user)
    @stranger = Factory.create(:user)
  end
  
  context "database" do
  
    it "should have an index on [creator_id]" do
      indexes = Roll.collection.index_information.values.map { |v| v["key"] }
      indexes.should include({"a"=>1})
    end
  
    it "should abbreviate creator_id as :a" do
      Roll.keys["creator_id"].abbr.should == :a
    end
  
  end
  
  context "followers" do
  
    it "should know if a user is following" do
      @roll.followed_by?(@user).should == false
    
      @roll.add_follower(@user)
      @roll.followed_by?(@user).should == true
    end
  
    it "should be able to add a follower, who should then know they're following this role" do
      @roll.add_follower(@user)
    
      @roll.followed_by?(@user).should == true
      @user.following_roll?(@roll).should == true
    end
    
    it "should email on add follower" do
      lambda {
        @roll.add_follower(@user)
      }.should change(ActionMailer::Base.deliveries,:size).by(1)
    end
    
    it "should not email on add follower if send_notification=false" do
      lambda {
        @roll.add_follower(@user, false)
      }.should change(ActionMailer::Base.deliveries,:size).by(0)
    end
    
    it "should not add follower if they're already following" do
      lambda {
        @roll.add_follower(@user)
      }.should change { @roll.following_users.count } .by(1)
      
      lambda {
        @roll.add_follower(@user).should == false
      }.should_not change { @roll.following_users.count }
    end
    
    it "should be able to remove a follower, who then knows they've unfollowed this role" do
      @roll.add_follower(@user)
      @roll.remove_follower(@user)
      
      @roll.followed_by?(@user).should == false
      @user.following_roll?(@roll).should == false
      @user.unfollowed_roll?(@roll).should == true
    end
    
    it "should not remove follower unless they're following" do
      lambda {
        @roll.remove_follower(@user).should == false
      }.should_not change { @roll.following_users.count }
    end
    
    it "should only remove the follower requested" do
      @roll.add_follower(@user)
      @roll.add_follower(@stranger)
      @roll.remove_follower(@stranger)
      
      @roll.followed_by?(@stranger).should == false
      @stranger.following_roll?(@roll).should == false
      @stranger.unfollowed_roll?(@roll).should == true
      
      @roll.followed_by?(@user).should == true
      @user.following_roll?(@roll).should == true
      @user.unfollowed_roll?(@roll).should == false
    end
    
    it "should be able to hold 1000 following users" do
      u = Factory.create(:user)
      
      1000.times do
        @roll.following_users << FollowingUser.new(:user => u)
      end
      @roll.save #should not raise an error
    end
    
    it "should return array of all followers' ids" do
      u1 = Factory.create(:user)
      @roll.add_follower(u1)
      u2 = Factory.create(:user)
      @roll.add_follower(u2)
      u3 = Factory.create(:user)
      @roll.add_follower(u3)
      
      user_ids = @roll.following_users_ids
      
      user_ids[0].should be_a(BSON::ObjectId)
      user_ids.include?(u1.id).should == true
      user_ids.include?(u2.id).should == true
      user_ids.include?(u3.id).should == true
    end
    
    it "should return array of all follower' models" do
      u1 = Factory.create(:user)
      @roll.add_follower(u1)
      u2 = Factory.create(:user)
      @roll.add_follower(u2)
      u3 = Factory.create(:user)
      @roll.add_follower(u3)
      
      user_models = @roll.following_users_models
      
      user_models[0].should be_a(User)
      user_models.include?(u1).should == true
      user_models.include?(u2).should == true
      user_models.include?(u3).should == true
    end
  
  end

  context "permissions" do
    
    it "should be viewable & invitable to by anybody (even non-logged in) if +public" do
      @roll.creator = @user
      @roll.public = true

      @roll.viewable_by?(nil).should == true
      
      @roll.viewable_by?(@user).should == true
      @roll.invitable_to_by?(@user).should == true
      @roll.viewable_by?(@stranger).should == true
      @roll.invitable_to_by?(@stranger).should == true
    end

    it "should be postable by anybody if +public and +collaborative" do
      @roll.public = true
      @roll.collaborative = true
    
      @roll.postable_by?(nil).should == true
      @roll.postable_by?(@stranger).should == true
    end

    it "should be postable only by the owner if +public and -collaborative" do
      @roll.creator = @user
      @roll.public = true
      @roll.collaborative = false
    
      @roll.postable_by?(@user).should == true
      @roll.postable_by?(@stranger).should == false
      @roll.postable_by?(nil).should == false
    end
  
    it "should be viewable, postable and invitable-to by followers if it's -public and +collaborative" do
      @roll.creator = @user
      @roll.public = false
      @roll.collaborative = true
    
      @roll.viewable_by?(@stranger).should == false
      @roll.invitable_to_by?(@stranger).should == false
      @roll.postable_by?(@stranger).should == false
      @roll.postable_by?(nil).should == false
    
      #get to know that stranger...
      # ie add them as a follower to a private collaborative roll
      @roll.add_follower(@stranger)
      @roll.viewable_by?(@stranger).should == true
      @roll.invitable_to_by?(@stranger).should == true
      @roll.postable_by?(@stranger).should == true
    end
    
    it "should be leavable iff user is not the creator" do
      @roll.leavable_by?(@stranger).should == true
    end
    
    it "should not be leavable if the user is the creator" do
      @roll.creator = @user
      @roll.leavable_by?(@user).should == false
    end
  
  end
    
end
