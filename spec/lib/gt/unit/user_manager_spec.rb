# encoding: UTF-8

require 'spec_helper'

require 'user_manager'

# UNIT test
describe GT::UserManager do
  before(:all) do
  end
  
  context "get_or_create_faux_user" do
    it "should get real User when one exists" do
      nick, provider, uid = "whatever", "fb", "123uid"
      u = User.new(:nickname => nick, :faux => false)
      auth = Authentication.new
      auth.provider = provider
      auth.uid = uid
      u.authentications << auth
      u.save
      
      u.persisted?.should == true
      
      lambda {
        GT::UserManager.get_or_create_faux_user(nick, provider, uid).should == u
      }.should_not change { User.count }
    end
    
    it "should get faux User when one exists" do
      nick, provider, uid = "whatever2", "fb", "123uid2"
      u = User.new(:nickname => nick, :faux => true)
      auth = Authentication.new
      auth.provider = provider
      auth.uid = uid
      u.authentications << auth
      u.save
      
      u.persisted?.should == true
      
      lambda {
        GT::UserManager.get_or_create_faux_user(nick, provider, uid).should == u
      }.should_not change { User.count }
    end
    
    it "should create a (persisted) faux User" do
      nick, provider, uid = "whatever3", "fb", "123uid3"
      lambda {
        u = GT::UserManager.get_or_create_faux_user(nick, provider, uid)
        u.class.should == User
        u.persisted?.should == true
        u.faux.should == true
      }.should change { User.count }.by(1)
    end
    
    it "should have a (persisted) public Roll on the User it creates" do
      nick, provider, uid = "whatever4", "fb", "123uid4"

      u = GT::UserManager.get_or_create_faux_user(nick, provider, uid)
      r = u.public_roll
      r.class.should == Roll
      r.persisted?.should == true
      r.public.should == true
      r.collaborative.should == false
      r.creator.should == u
    end
    
    it "should have a correct Authentication on the User it creates" do
      nick, provider, uid = "whatever5", "fb", "123uid5"

      u = GT::UserManager.get_or_create_faux_user(nick, provider, uid)
      u.authentications.size.should == 1
      auth = u.authentications[0]
      auth.class.should == Authentication
      auth.provider.should == provider
      auth.uid.should == uid
    end
    
    context "nickname fixing" do
      it "should change space to underscore" do
        nick, provider, uid = "whatever 6", "fb", "123uid6"
        GT::UserManager.get_or_create_faux_user(nick, provider, uid).nickname.should == "whatever_6"
      end
      
      it "should remove quote marks" do
        nick, provider, uid = "whatever'‘’\"`7", "fb", "123uid7"
        GT::UserManager.get_or_create_faux_user(nick, provider, uid).nickname.should == "whatever7"
      end
      
      it "should make the nickname unique" do
        nick, provider, uid = "whatever 6", "fb", "123uid8"
        GT::UserManager.get_or_create_faux_user(nick, provider, uid).nickname.should_not == "whatever_6"
        
        nick, provider, uid = "whatever 6", "fb", "123uid82"
        GT::UserManager.get_or_create_faux_user(nick, provider, uid).nickname.should_not == "whatever_6"
      end
    end
    
    it "should set downcase nickname" do
      nick, provider, uid = "WHATever1", "twt", "123uid1"
      u = GT::UserManager.get_or_create_faux_user(nick, provider, uid)
      u.nickname.should == "WHATever1"
      u.downcase_nickname.should == "whatever1"
    end
    
  end
  
  context "create_user" do
    
    #TODO

  end
  
end
  