require 'spec_helper'

#Functional: hit the database, treat model as black box
describe User do
  before(:each) do
    @user = User.create( :nickname => "#{rand.to_s}-#{Time.now.to_f}" )
  end
  
  context "database" do
    
    it "should have an index on [nickname], [downcase_nickname], [primary_email], [authentications.uid], [authentications.nickname]" do
      indexes = User.collection.index_information.values.map { |v| v["key"] }
      indexes.should include({"nickname"=>1})
      indexes.should include({"downcase_nickname"=>1})
      indexes.should include({"primary_email"=>1})
      indexes.should include({"authentications.uid"=>1})
      indexes.should include({"authentications.nickname"=>1})
    end
    
    it "should be savable and loadable" do
      @user.persisted?.should == true
      User.find(@user.id).should == @user      
      User.find(@user.id).id.should == @user.id
    end
  
    it "should not save if user w/ same nickname already exists" do
      lambda {
        User.exists?(:nickname => @user.nickname).should == true
        u = User.new(:nickname => @user.nickname)
        u.save.should == false
        u.persisted?.should == false
      }.should change {User.count}.by(0)
    end
  
  end
  
  context "rolls" do
    before(:each) do
      @roll = Roll.new
    end
    
    it "should know what Rolls it's following" do
      @user.following_roll?(@roll).should == false
      @roll.add_follower(@user)
      @user.following_roll?(@roll).should == true
    end
    
    it "should know what Rolls it's un-followed" do
      @user.unfollowed_roll?(@roll).should == false
      @roll.remove_follower(@user)
      @user.unfollowed_roll?(@roll).should == true
    end
    
  end
  
end
