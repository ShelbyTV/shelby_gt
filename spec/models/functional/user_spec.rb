require 'spec_helper'

#Functional: hit the database, treat model as black box
describe User do
  before(:each) do
    @user = Factory.create(:user)
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
        u = User.new(:nickname => "this_is_sooooo_unique")
        u.downcase_nickname = "this_is_sooooo_unique"
        u.save
        u.persisted?.should == true
      }.should change {User.count} .by 1
      lambda {
        u = User.new
        u.nickname = "this_is_sooooo_unique"
        u.downcase_nickname = "this_is_sooooo_unique"
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

    it "should update the title of its public roll when it's nickname is updated if the roll matches the nickname" do
      @roll.title = @user.nickname
      @user.public_roll = @roll
      @user.nickname = "newnickname"
      @user.save
      @user.public_roll.title.should == "newnickname"
      @user.public_roll.changed?.should == false
    end

    it "should NOT update the title of its public roll when it's nickname is updated if the roll doesn't match the nickname" do
      @roll.title = "not-my-nickname"
      @user.public_roll = @roll
      @user.nickname = "newnickname"
      @user.save
      @user.public_roll.title.should == "not-my-nickname"
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
  
  context "nickname" do
    it "should update downcase_nickname when you update nickname" do
      new_nick = "someTHINGnewaAaAaAaA"
      u = Factory.create(:user)
      u.nickname = new_nick
      u.save
      u.reload
      u.downcase_nickname.should == new_nick.downcase
    end
    
    #UserManager performs this operation manually (for new users from Arnold or signup), want to make sure we don't do it twice
    it "should not run User#ensure_valid_unique_nickname on create" do
      nick = "random_unique_nick_name-o0823u"
      u = User.new
      u.should_receive(:ensure_valid_unique_nickname).exactly(0).times
      
      u.nickname = nick
      u.downcase_nickname = nick
      u.save
      u.reload
      u.downcase_nickname.should == nick
    end
  end
  
end
