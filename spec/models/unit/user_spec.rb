# encoding: utf-8
require 'spec_helper'

# Unit: don't hit DB, check on internals of model
describe User do
  before(:each) do
    @user = User.new
  end
  
  it "should use the database user" do
    @user.database.name.should =~ /.*user/
  end
  

  
  

  

  

  
  it "should be able to update auth tokens" do
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

    u.authentications << Authentication.build_from_omniauth(omniauth_hash)
    
    # UPDATE
    updated_omniauth_hash = {
      'provider' => "twitter",
      'uid' => '33',
      'credentials' => {
        'token' => "NEW--token",
        'secret' => 'NEW--secret'
      }
    }
    u.update_authentication_tokens!(updated_omniauth_hash)
    
    auth = u.authentication_by_provider_and_uid( "twitter", "33" )
    auth.should_not == nil
    auth.provider.should == "twitter"
    auth.uid.should == "33"
    auth.oauth_token.should == "NEW--token"
    auth.oauth_secret.should == "NEW--secret"
  end


  
  it "should replace whitespace in the nickname with underscore" do
    u = Factory.build( :user, :nickname => "dan spinosa")
    u.valid?.should eql(true)
    u.nickname.should eql("dan_spinosa")
    
    u = Factory.build( :user, :nickname => " spinosa")
    u.valid?.should eql(true)
    u.nickname.should eql("_spinosa")
    
    u = Factory.build( :user, :nickname => "spinosa ")
    u.valid?.should eql(true)
    u.nickname.should eql("spinosa_")
    
    u = Factory.build( :user, :nickname => "spinDr")
    u.valid?.should eql(true)
  end
  
  it "should not validate with route prefixes in the nickname" do
    u = Factory.build( :user, :nickname => "users")
    u.valid?.should eql(false)
    
    u = Factory.build( :user, :nickname => "authentications")
    u.valid?.should eql(false)
    
    u = Factory.build( :user, :nickname => "setup")
    u.valid?.should eql(false)
  end

  it "should validate nickname w/ utf8 support, dot, underscore and/or hyphen" do
    Factory.build(:user, :nickname => "J.Marie_Teis-Sèdre").valid?.should == true
    Factory.build(:user, :nickname => "보통그냥").valid?.should == true
    Factory.build(:user, :nickname => "Boris Šebošík").valid?.should == true
    Factory.build(:user, :nickname => "Олег_Бородин").valid?.should == true
    Factory.build(:user, :nickname => "Станислав_Станислав").valid?.should == true
    Factory.build(:user, :nickname => "厚任_賴厚任").valid?.should == true
    Factory.build(:user, :nickname => "Thập_Lục_Thập").valid?.should == true
    Factory.build(:user, :nickname => "ธีระพงษ์_อารีเอื้อ").valid?.should == true
    Factory.build(:user, :nickname => "鎮順_陳鎮順").valid?.should == true
    Factory.build(:user, :nickname => "Андрей_Бабакاسي").valid?.should == true
    Factory.build(:user, :nickname => "ابراهي_اليم").valid?.should == true
    Factory.build(:user, :nickname => "Παναγής_Μέγαρα").valid?.should == true
    Factory.build(:user, :nickname => "அன்புடன்_ஆனந்தகுமார்").valid?.should == true
    Factory.build(:user, :nickname => "אבו_ודיע").valid?.should == true
    Factory.build(:user, :nickname => "ომარი_დევიძე").valid?.should == true
    Factory.build(:user, :nickname => "みさお_みさお").valid?.should == true
    Factory.build(:user, :nickname => "たくや_たくや").valid?.should == true
    Factory.build(:user, :nickname => "ヴィクタ").valid?.should == true
    #Factory.build(:user, :nickname => "FILL_ME_IN").valid?.should == true
  end

  it "should remove invalid punctuation from nickname" do
    u = Factory.build(:user, :nickname => "dan‘s’")
    u.valid?.should == true
    u.nickname.should == "dans"
    
    u = Factory.build(:user, :nickname => "'Astrid_Carolina_Valdez")
    u.valid?.should == true
    u.nickname.should == "Astrid_Carolina_Valdez"
  end

  it "should build a valid user itself from omniauth hash" do
    omniauth_hash = {
      'user_info' => {
        'name' => "the name",
        'nickname' => "some_nick",
        'garbage' => 99
      },
      'more_garbage' => Date.new
    }
    
    from_omni_user = User.new_from_omniauth(omniauth_hash)
    
    from_omni_user.valid?.should eql(true)
  end
  
  it 'should not save when an auth is added' do
    omniauth_hash = {
      'user_info' => {
        'name' => "the name",
        'nickname' => "some nick",
        'garbage' => 99
      },
      'credentials' => {
        'token' => 'toke', 'secret' => 'seeek'
      },
      'more_garbage' => Date.new
    }
    
    from_omni_user = User.new_from_omniauth(omniauth_hash)
    from_omni_user.new?.should == true
    
    from_omni_user.authentications << (a = Authentication.build_from_omniauth(omniauth_hash))
    from_omni_user.new?.should == true
    a.new?.should == true
    
    from_omni_user.valid?.should == true
    from_omni_user.save.should == true
    a.new?.should == false
  end
  
  it 'should handle blank nickname' do
    omniauth_hash = {
      'user_info' => {
        'name' => "the name",
        'garbage' => 99
      },
      'more_garbage' => Date.new
    }
    
    from_omni_user = User.new_from_omniauth(omniauth_hash)
    
    from_omni_user.valid?.should eql(true)
  end
  
  it 'should handle werid facebook nickname' do
    omniauth_hash = {
      'user_info' => {
        'name' => "the name",
        'nickname' => "profile.php?id=676553813",
        'garbage' => 99
      },
      'more_garbage' => Date.new
    }
    
    from_omni_user = User.new_from_omniauth(omniauth_hash)
    
    from_omni_user.valid?.should eql(true)
    from_omni_user.save
    from_omni_user.nickname.start_with?("the_name").should == true
  end

  it "should copy nickname downcased" do
    u = Factory.create(:user, :nickname => "Something_inCAPS" )
    nick = u.nickname
    u.reload.downcase_nickname.should == nick.downcase
  end

  it "should be findable by case-insensitive nickname" do
    u = Factory.create(:user, :nickname => "Spinosa" )
    User.find_by_nickname("spinosa").should be_a(User)
    User.find_by_nickname("Spinosa").should be_a(User)
    User.find_by_nickname("spinOSa").should be_a(User)
    User.find_by_nickname("spin osa").should be(nil)
    
    Factory.create(:user, :nickname => "Frank_Lazio_JR" )
    User.find_by_nickname("frank_lazio_jr").should be_a(User)
  end
  
  it "should not return root in json" do
    JSON.parse(@user.to_json).size.should be > 1
  end

  it "should make sure it's finding user by entire nickname only" do
    u = Factory.create(:user, :nickname => "this_is_the_nickname")
    nick = u.nickname
    User.find_by_nickname(nick[0..nick.length-2]).should == nil
    User.find_by_nickname(nick[2..nick.length]).should == nil
    User.find_by_nickname(nick).should == u
  end
  
  it "should always have preferences once created" do
    u = Factory.create(:user)
    u.preferences.email_updates.should == true
    u.preferences.like_notifications.should == true
    u.preferences.watched_notifications.should == true
    u.preferences.quiet_mode.should == nil
  end

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
