require 'spec_helper'

#Functional: hit the database, treat model as black box
describe User do
  before(:each) do
    @user = User.create( :nickname => "#{rand.to_s}-#{Time.now.to_f}" )
  end
  
  context "database" do
 
    it "should have an identity map" do
      u = User.new
      u.save
      User.identity_map.size.should > 0
    end

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
      }.should_not change {User.count}
    end
    
    it "should not be savable w/o a nickname" do
      lambda {
        u = User.new(:nickname => nil)
        u.save.should == false
        u.nickname = ''
        u.save.should == false
        u.nickname = ' '
        u.save.should == false
      }.should_not change {User.count}
    end
    
    it "should throw error when trying to create a User where index (ie nickname) already exists" do
      lambda {
        User.create(:nickname => "this_is_sooooo_unique").persisted?.should == true
      }.should change {User.count} .by 1
      lambda {
        u = User.new
        u.nickname = "this_is_sooooo_unique"
        u.save(:validate => false)
      }.should raise_error Mongo::OperationFailure
    end

  end
  
  context "rolls" do
    before(:each) do
      @roll = Factory.build(:roll)
      @roll.creator = Factory.create(:user)
      @roll.save
    end
    
    it "should know what Rolls it's following" do
      @user.following_roll?(@roll).should == false
      @roll.add_follower(@user)
      @user.following_roll?(@roll).should == true
    end
    
    it "should know what Rolls it's un-followed" do
      @roll.add_follower(@user)
      @user.unfollowed_roll?(@roll).should == false
      @roll.remove_follower(@user)
      @user.unfollowed_roll?(@roll).should == true
    end

    it "should update the title of its public roll when it's nickname is updated" do
      @user.public_roll = @roll
      @user.nickname = "newnickname"
      @user.save
      @user.public_roll.title.should == "newnickname"
      @user.public_roll.changed?.should == false
    end

  end
  
  context "devise" do
    
    it "should call remember_me and return a string" do
      @user.remember_me!
      @user.remember_token.class.should eq(String)
    end
    
    it "should not hit db when calling remember_me" do
      User.should_receive(:first).exactly(0).times
      @user.remember_me!
    end
    
  end
  
end
