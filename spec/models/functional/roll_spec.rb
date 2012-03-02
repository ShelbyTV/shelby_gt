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
  
  end

  context "permissions" do
    
    it "should be viewable & invitable to by anybody if +public" do
      @roll.creator = @user
      @roll.public = true
    
      @roll.viewable_by?(@user).should == true
      @roll.invitable_to_by?(@user).should == true
      @roll.viewable_by?(@stranger).should == true
      @roll.invitable_to_by?(@stranger).should == true
    end

    it "should be postable by anybody if +public and +collaborative" do
      @roll.public = true
      @roll.collaborative = true
    
      @roll.postable_by?(@stranger).should == true
    end

    it "should be postable only by the owner if +public and -collaborative" do
      @roll.creator = @user
      @roll.public = true
      @roll.collaborative = false
    
      @roll.postable_by?(@user).should == true
      @roll.postable_by?(@stranger).should == false
    end
  
    it "should be viewable, postable and invitable-to by followers if it's -public and +collaborative" do
      @roll.creator = @user
      @roll.public = false
      @roll.collaborative = true
    
      @roll.viewable_by?(@stranger).should == false
      @roll.invitable_to_by?(@stranger).should == false
      @roll.postable_by?(@stranger).should == false
    
      #get to know that stranger...
      # ie add them as a follower to a private collaborative roll
      @roll.add_follower(@stranger)
      @roll.viewable_by?(@stranger).should == true
      @roll.invitable_to_by?(@stranger).should == true
      @roll.postable_by?(@stranger).should == true
    end
  
  end
  
end
