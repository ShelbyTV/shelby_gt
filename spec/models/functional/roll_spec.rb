require 'spec_helper'

#Functional: hit the database, treat model as black box
describe Roll do
  before(:each) do
    @roll = Roll.new
    @user = User.new
    @stranger = User.new
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
      1000.times do
        @roll.add_follower(Factory.create(:user))
      end
      @roll.save #should not raise an error
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
  
  context "get or create short links" do
    before(:each) do
      @roll = Factory.create(:roll, :creator => Factory.create(:user))
    end
    
    it "should return a short link that we have already" do
      @roll.short_links[:twitter] = "http://i.ro.ck"; @roll.save
      r = @roll.get_or_create_shortlink(["twitter"])
      r.should eq(@roll.short_links)
    end
    
    it "should get a new short link if it doesnt exist" do
      resp = {"awesm_urls" => [{"service"=>"twitter", "parent"=>nil, "original_url"=>"http://henrysztul.info", "redirect_url"=>"http://henrysztul.info?awesm=shl.by_4", "awesm_id"=>"shl.by_4", "awesm_url"=>"http://shl.by/4", "user_id"=>nil, "path"=>"4", "channel"=>"twitter", "domain"=>"shl.by"}]}
      Awesm::Url.stub(:batch).and_return([200, resp])
      r = @roll.get_or_create_shortlink(["twitter"])
      r["twitter"].should eq(resp["awesm_urls"].first["awesm_url"])
    end
    
    it "should return error if we dont pass an array" do
      lambda { @roll.get_or_create_shortlink("test") }.should raise_error(ArgumentError)
    end
    
  end
  
  
  
end
