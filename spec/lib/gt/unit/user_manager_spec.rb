# encoding: UTF-8

require 'spec_helper'

require 'user_manager'
require 'authentication_builder'
require 'predator_manager'

# UNIT test
describe GT::UserManager do
  
  context "get_or_create_faux_user" do
    it "should get real User when one exists" do
      nick, provider, uid = "whatever", "fb", "123uid"
      u = User.new(:nickname => nick, :faux => User::FAUX_STATUS[:false])
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
      u = User.new(:nickname => nick, :faux => User::FAUX_STATUS[:true])
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
    
    it "should add a public roll to existing user if they're missing it" do
      nick, provider, uid = "whatever--", "fb--", "123uid--"
      u = User.new(:nickname => nick, :faux => User::FAUX_STATUS[:false])
      auth = Authentication.new
      auth.provider = provider
      auth.uid = uid
      u.authentications << auth
      u.save
      
      u.persisted?.should == true
      u.public_roll.should == nil
      
      lambda {
        usr = GT::UserManager.get_or_create_faux_user(nick, provider, uid)
        usr.should == u
        usr.public_roll.class.should == Roll
        usr.public_roll.persisted?.should == true
      }.should_not change { User.count }
    end
    
    it "should create a (persisted) faux User" do
      nick, provider, uid = "whatever3", "fb", "123uid3"
      lambda {
        u = GT::UserManager.get_or_create_faux_user(nick, provider, uid)
        u.class.should == User
        u.persisted?.should == true
        u.faux.should == User::FAUX_STATUS[:true]
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
  
  context "convert_faux_user_to_real" do
    before(:each) do
      @omniauth_hash = {
        'provider' => "twitter",
        'uid' => '33',
        'credentials' => {
          'token' => "somelongtoken",
          'secret' => 'foreskin'
        },
        'info' => {
          'name' => 'some name',
          'nickname' => @nickname,
          'image' => "http://original.com/image_normal.png",
          'garbage' => 'truck'
        },
        'garbage' => 'truck'
      }
      
      nick, provider, uid = "whatever3", "fb", "123uid3"
      @faux_u = GT::UserManager.get_or_create_faux_user(nick, provider, uid)
    end
    
    it "should convert a (persisted) faux User to real user" do
      real_u, new_auth = GT::UserManager.convert_faux_user_to_real(@faux_u, @omniauth_hash)
      real_u.class.should == User
      real_u.persisted?.should == true
      real_u.faux.should == User::FAUX_STATUS[:converted]
    end

    it "should have one authentication with an oauth token" do
      real_u, new_auth = GT::UserManager.convert_faux_user_to_real(@faux_u, @omniauth_hash)
      real_u.authentications.length.should eq(1)
      new_auth.oauth_token.should eq(@omniauth_hash["credentials"]["token"])
    end
    
    it "should have preferences set" do
      real_u, new_auth = GT::UserManager.convert_faux_user_to_real(@faux_u, @omniauth_hash)
      real_u.preferences.class.should eq(Preferences)
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
          'info' => {
            'name' => 'some name',
            'nickname' => @nickname,
            'image' => "http://original.com/image_normal.png",
            'garbage' => 'truck'
          },
          'garbage' => 'truck'
        }

      end
      
      it "should build a valid user itself from omniauth hash" do
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash)
        u.nickname.should eq(@nickname)
      end
      
      it "should change nickname if it's taken" do
        current_user = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash)
        GT::UserManager.create_new_user_from_omniauth(@omniauth_hash).nickname.should_not == current_user.nickname
      end
      
      it "should replace whitespace in the nickname with underscore" do
        @omniauth_hash["info"]["nickname"] = "dan spinosa"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash)
        u.valid?.should eql(true)
        u.nickname.should eql("dan_spinosa")

        @omniauth_hash["info"]["nickname"] = " spinosa"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash)
        u.valid?.should eql(true)
        u.nickname.should eql("_spinosa")

        @omniauth_hash["info"]["nickname"] = "spinosa "
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash)
        u.valid?.should eql(true)
        u.nickname.should eql("spinosa_")

        @omniauth_hash["info"]["nickname"] = "spinDr"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash)
        u.valid?.should eql(true)
      end
      
      it "should remove invalid punctuation from nickname" do
        @omniauth_hash["info"]["nickname"] = "dan‘s’"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash)
        u.valid?.should == true
        u.nickname.should == "dans"

        @omniauth_hash["info"]["nickname"] = "'Astrid_Carolina_Valdez"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash)
        u.valid?.should == true
        u.nickname.should == "Astrid_Carolina_Valdez"
      end
      
      it "should validate nickname w/ utf8 support, dot, underscore and/or hyphen" do
        @omniauth_hash['info']['nickname'] = "J.Marie_Teis-Sèdre"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash).should_not == nil
        @omniauth_hash['info']['nickname'] = "보통그냥"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash).should_not == nil
        @omniauth_hash['info']['nickname'] = "Boris Šebošík"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash).should_not == nil
        @omniauth_hash['info']['nickname'] = "Олег_Бородин"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash).should_not == nil
        @omniauth_hash['info']['nickname'] = "Станислав_Станислав"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash).should_not == nil
        @omniauth_hash['info']['nickname'] = "厚任_賴厚任"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash).should_not == nil
        @omniauth_hash['info']['nickname'] = "Thập_Lục_Thập"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash).should_not == nil
        @omniauth_hash['info']['nickname'] = "ธีระพงษ์_อารีเอื้อ"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash).should_not == nil
        @omniauth_hash['info']['nickname'] = "鎮順_陳鎮順"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash).should_not == nil
        @omniauth_hash['info']['nickname'] = "Андрей_Бабакاسي"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash).should_not == nil
        @omniauth_hash['info']['nickname'] = "ابراهي_اليم"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash).should_not == nil
        @omniauth_hash['info']['nickname'] = "Παναγής_Μέγαρα"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash).should_not == nil
        @omniauth_hash['info']['nickname'] = "அன்புடன்_ஆனந்தகுமார்"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash).should_not == nil
        @omniauth_hash['info']['nickname'] = "אבו_ודיע"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash).should_not == nil
        @omniauth_hash['info']['nickname'] = "ომარი_დევიძე"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash).should_not == nil
        @omniauth_hash['info']['nickname'] = "みさお_みさお"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash).should_not == nil
        @omniauth_hash['info']['nickname'] = "たくや_たくや"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash).should_not == nil
        @omniauth_hash['info']['nickname'] = "ヴィクタ"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash).should_not == nil

        #@omniauth_hash['info']['nickname'] = "FILL_ME_IN"
        #u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash).should_not == nil
      end
      
      it 'should handle blank nickname' do
        omniauth_hash = {
          'credentials' => {
            'token' => "somelongtoken",
            'secret' => 'foreskin',
            'garbage' => 'truck'
          },
          'info' => {
            'name' => 'some name'
          },
          'more_garbage' => Date.new
        }
        u = GT::UserManager.create_new_user_from_omniauth(omniauth_hash)

        u.valid?.should eql(true)
      end
      
      it 'should handle werid facebook nickname' do
        omniauth_hash = {
          'credentials' => {
            'token' => "somelongtoken",
            'secret' => 'foreskin',
            'garbage' => 'truck'
          },
          'info' => {
            'name' => "the name",
            'nickname' => "profile.php?id=676553813",
            'garbage' => 99
          },
          'more_garbage' => Date.new
        }

        u = GT::UserManager.create_new_user_from_omniauth(omniauth_hash)

        u.valid?.should eql(true)
        u.nickname.start_with?("the_name").should == true
      end

      it "should copy nickname downcased" do
        @omniauth_hash["info"]["nickname"] = "SomeInCAPS"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash)
        nick = u.nickname
        u.reload.downcase_nickname.should == nick.downcase
      end

      it "should be findable by case-insensitive nickname" do
        @omniauth_hash["info"]["nickname"] = "Spinosa"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash)
        User.find_by_nickname("spinosa").should be_a(User)
        User.find_by_nickname("Spinosa").should be_a(User)
        User.find_by_nickname("spinOSa").should be_a(User)
        User.find_by_nickname("spin osa").should be(nil)

        @omniauth_hash["info"]["nickname"] = "Frank_Lazio_JR"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash)
        User.find_by_nickname("frank_lazio_jr").should be_a(User)
      end
      
      it "should make sure it's finding user by entire nickname only" do
        @omniauth_hash["info"]["nickname"] = "this_is_the_nickname"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash)

        nick = u.nickname
        User.find_by_nickname(nick[0..nick.length-2]).should == nil
        User.find_by_nickname(nick[2..nick.length]).should == nil
        User.find_by_nickname(nick).should == u
      end

      it "should always have preferences once created" do
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash)
        u.preferences.email_updates.should == true
        u.preferences.like_notifications.should == true
        u.preferences.watched_notifications.should == true
        u.preferences.quiet_mode.should == nil
      end
      
    end
    
    context "from facebook" do
      it 'should handle creation from fb rather than omniauth' do
        # this is a shitty test...
        u = Factory.create(:user)
        fb_hash = {
          'user_name' => "the.username",
          'name' => "the name",
          'and_more' => 9009
        }

        User.stub(:new_from_facebook).with( fb_hash ).and_return( @user )

        u.valid?.should eql(true)
      end
      
    end
    
  end
  
  context "update user" do
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
        'info' => {
          'name' => 'some name',
          'nickname' => @nickname,
          'image' => "http://original.com/image_normal.png",
          'garbage' => 'truck'
        },
        'garbage' => 'truck'
      }

    end
    it "should be able to update auth tokens" do
      u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash)
      
      # UPDATE
      @omniauth_hash['credentials']['token'] = "NEW--token"
      @omniauth_hash['credentials']['secret'] = "NEW--secret"
      
      GT::UserManager.start_user_sign_in(u, @omniauth_hash)

      auth = GT::AuthenticationBuilder.authentication_by_provider_and_uid(u, "twitter", "33" )
      auth.should_not == nil
      auth.provider.should == "twitter"
      auth.uid.should == "33"
      auth.oauth_token.should == "NEW--token"
      auth.oauth_secret.should == "NEW--secret"
    end

    it "should add a new auth to an existing user" do
      u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash)

      new_omniauth_hash = {
        'provider' => "facebook",
        'uid' => '33',
        'credentials' => {
          'token' => "somelongtoken",
          'secret' => 'foreskin',
          'garbage' => 'truck'
        },
        'info' => {
          'name' => 'some name',
          'nickname' => 'ironically nick',
          'garbage' => 'truck'
        },
        'garbage' => 'truck'
      }
      
      updated_u = GT::UserManager.add_new_auth_from_omniauth(u, new_omniauth_hash)
      u.id.should == updated_u.id
    end
  end
  
end
  