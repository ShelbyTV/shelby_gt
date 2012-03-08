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
    
    context "from omniauth" do
      before(:each) do
        @nickname = "nick-#{rand.to_s}"
        @omniauth_hash = {
          'provider' => "twitter",
          'uid' => '33',
          'credentials' => {
            'token' => "somelongtoken",
            'secret' => 'foreskin',
            'garbage' => 'truck'
          },
          'user_info' => {
            'name' => 'some name',
            'nickname' => @nickname,
            'image' => "http://original.com/image_normal.png",
            'garbage' => 'truck'
          },
          'garbage' => 'truck'
        }

      end
      
      it "should create a new user and have a nickname" do
        u = GT::UserManager.create_new_from_omniauth(@omniauth_hash)
        u.nickname.should eq(@nickname)
      end
      
      it "should have_provider from its authentications" do
        u = Factory.create(:user)
        u.authentications << GT::UserManager.send(:build_authentication_from_omniauth, @omniauth_hash)
        u.has_provider('twitter').should eq(true)
      end
      
      it "should not have_provider not in its authentications" do
        u = Factory.create(:user)
        u.authentications << GT::UserManager.send(:build_authentication_from_omniauth, @omniauth_hash)
        u.has_provider('your mom').should eq(false)
      end
      
      it "should incorporate authentication user image, and larger user image if twitter" do
        u = Factory.create(:user)
        auth = GT::UserManager.send(:build_authentication_from_omniauth, @omniauth_hash)
        u.authentications << auth
        
        GT::UserManager.send(:fill_in_user_with_auth_info, u, auth)
        
        u.user_image.should == "http://original.com/image_normal.png"
        u.user_image_original.should == "http://original.com/image.png"
      end
      
      it "should incorporate auth user image, and larger user image if twitter, but not if it's a default image" do
        u = Factory.create(:user)
        omniauth_hash = {
          'provider' => "twitter",
          'uid' => '33',
          'credentials' => {
            'token' => "somelongtoken",
            'secret' => 'foreskin'
          },
          'user_info' => {
            'name' => 'some name',
            'nickname' => 'ironically nick',
            'garbage' => 'truck',
            'image' => "http://original.com/default_profile_6_normal.png"
          }
        }

        auth = GT::UserManager.send(:build_authentication_from_omniauth, omniauth_hash)
        GT::UserManager.send(:fill_in_user_with_auth_info, u, auth)
        u.user_image.should == "http://original.com/default_profile_6_normal.png"
        u.user_image_original.should == nil
      end
      
      it "should be able to get auth from provider and id" do
        u = Factory.create(:user)
        u.authentications << GT::UserManager.send(:build_authentication_from_omniauth, @omniauth_hash)

        auth = u.authentication_by_provider_and_uid( "twitter", "33" )
        auth.should_not == nil
        auth.provider.should == "twitter"
        auth.uid.should == "33"
        auth.oauth_token.should == "somelongtoken"
        auth.oauth_secret.should == "foreskin"
      end
      
      it "should change nickname if it's taken" do
        current_user = GT::UserManager.create_new_from_omniauth(@omniauth_hash)
        GT::UserManager.create_new_from_omniauth(@omniauth_hash).nickname.should_not == current_user.nickname
      end
      
      it "should replace whitespace in the nickname with underscore" do
        @omniauth_hash["user_info"]["nickname"] = "dan spinosa"
        u = GT::UserManager.create_new_from_omniauth(@omniauth_hash)
        u.valid?.should eql(true)
        u.nickname.should eql("dan_spinosa")

        @omniauth_hash["user_info"]["nickname"] = " spinosa"
        u = GT::UserManager.create_new_from_omniauth(@omniauth_hash)
        u.valid?.should eql(true)
        u.nickname.should eql("_spinosa")

        @omniauth_hash["user_info"]["nickname"] = "spinosa "
        u = GT::UserManager.create_new_from_omniauth(@omniauth_hash)
        u.valid?.should eql(true)
        u.nickname.should eql("spinosa_")

        @omniauth_hash["user_info"]["nickname"] = "spinDr"
        u = GT::UserManager.create_new_from_omniauth(@omniauth_hash)
        u.valid?.should eql(true)
      end
      
      it "should remove invalid punctuation from nickname" do
        @omniauth_hash["user_info"]["nickname"] = "dan‘s’"
        u = GT::UserManager.create_new_from_omniauth(@omniauth_hash)
        u.valid?.should == true
        u.nickname.should == "dans"

        @omniauth_hash["user_info"]["nickname"] = "'Astrid_Carolina_Valdez"
        u = GT::UserManager.create_new_from_omniauth(@omniauth_hash)
        u.valid?.should == true
        u.nickname.should == "Astrid_Carolina_Valdez"
      end
      
      
      
    end
    
    context "from facebook"
    
  end
  
end
  