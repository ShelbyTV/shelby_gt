# encoding: UTF-8

require 'spec_helper'

require 'user_manager'
require 'authentication_builder'
require 'predator_manager'

# UNIT test
describe GT::UserManager do

  context "get_or_create_faux_user" do
    before(:each) do
      # we sleep when finding a new user, need to stub that
      EventMachine::Synchrony.stub(:sleep)
    end

    it "should raise an error if nickname is invalid" do
      lambda {
        GT::UserManager.get_or_create_faux_user('', 'provider', 'uid')
      }.should raise_error(ArgumentError)
    end
    
    it "should raise an error if provider is invalid" do
      lambda {
        GT::UserManager.get_or_create_faux_user('nick', '', 'uid')
      }.should raise_error(ArgumentError)
    end
    
    it "should raise an error if uid is invalid" do
      lambda {
        GT::UserManager.get_or_create_faux_user('nick', 'provider', '')
      }.should raise_error(ArgumentError)
    end
    
    it "should get real User when one exists" do
      nick, provider, uid = "whatever", "fb", "123uid"
      u = User.new(:nickname => nick)
      u.faux = User::FAUX_STATUS[:true]
      u.downcase_nickname = nick
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
      u = User.new(:nickname => nick)
      u.faux = User::FAUX_STATUS[:true]
      u.downcase_nickname = nick
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
      u = User.new(:nickname => nick)
      u.faux = User::FAUX_STATUS[:true]
      u.downcase_nickname = nick
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
    
    it "should add a watch_later_roll, upvoted_roll, viewed_roll, public_roll to existing user if they're missing it" do
      nick, provider, uid = "whatever--b-", "fb--", "123uid--b-"
      thumb_url = "some://thumb.url"
      u = User.new(:nickname => nick)
      u.faux = User::FAUX_STATUS[:true]
      u.downcase_nickname = nick
      u.user_image = thumb_url
      auth = Authentication.new
      auth.provider = provider
      auth.uid = uid
      u.authentications << auth
      u.save
      
      u.persisted?.should == true
      u.watch_later_roll.should == nil
      u.public_roll.should == nil
      
      lambda {
        usr = GT::UserManager.get_or_create_faux_user(nick, provider, uid)
        usr.should == u
        usr.watch_later_roll.class.should == Roll
        usr.watch_later_roll.persisted?.should == true
        usr.watch_later_roll.roll_type.should == Roll::TYPES[:special_watch_later]
        
        usr.viewed_roll.class.should == Roll
        usr.viewed_roll.persisted?.should == true
        usr.viewed_roll.roll_type.should == Roll::TYPES[:special_viewed]

        usr.upvoted_roll.class.should == Roll
        usr.upvoted_roll.upvoted_roll.should == true
        usr.upvoted_roll.persisted?.should == true
        usr.upvoted_roll.roll_type.should == Roll::TYPES[:special_upvoted]
                
        usr.public_roll.class.should == Roll
        usr.public_roll.persisted?.should == true
        usr.public_roll.creator_thumbnail_url.should == thumb_url
        usr.public_roll.roll_type.should == Roll::TYPES[:special_public]
      }.should_not change { User.count }
    end
    
    it "should create a (persisted) faux User" do
      nick, provider, uid = "whatever3", "fb", "123uid3"
      thumb_url = "some:://thumb.url"
      lambda {
        u = GT::UserManager.get_or_create_faux_user(nick, provider, uid, {:user_thumbnail_url => thumb_url})
        u.class.should == User
        u.persisted?.should == true
        u.faux.should == User::FAUX_STATUS[:true]
        u.user_image.should == thumb_url
      }.should change { User.count }.by(1)
    end
    
    it "should handle Mongo::OperationFailure (due to duplicate nickname on user) when creating a faux User" do
      GT::UserManager.should_receive(:ensure_valid_unique_nickname!).and_raise(Mongo::OperationFailure)
      
      nick, provider, uid = "whatever3", "fb", "123uid3--xx--"
      thumb_url = "some:://thumb.url"
      
      u = "blah"
      lambda {
        u = GT::UserManager.get_or_create_faux_user(nick, provider, uid, {:user_thumbnail_url => thumb_url})
      }.should_not raise_error(Mongo::OperationFailure)
      u.should == nil
    end
    
    it "should handle Mongo::OperationFailure (due to timing issue) and recover by returning the correct user" do
      GT::UserManager.should_receive(:ensure_valid_unique_nickname!).and_raise(Mongo::OperationFailure)
      
      #User.first(...) will first return nil, then will return a User, we want that User!
      User.should_receive(:first).and_return(nil, :the_user)
      
      nick, provider, uid = "whatever3", "fb", "123uid3--xx--"
      thumb_url = "some:://thumb.url"
      
      u = nil
      lambda {
        u = GT::UserManager.get_or_create_faux_user(nick, provider, uid, {:user_thumbnail_url => thumb_url})
      }.should_not raise_error(Mongo::OperationFailure)
      u.should == :the_user
    end
    
    it "should create and persist public, watch_later, upvoted, viewed rolls on faux user when created" do
      nick, provider, uid = "whatever3-b", "fb", "123uid3-b"
      lambda {
        u = GT::UserManager.get_or_create_faux_user(nick, provider, uid)

        u.public_roll.class.should == Roll
        u.public_roll.persisted?.should == true
        
        u.watch_later_roll.class.should == Roll
        u.watch_later_roll.persisted?.should == true
        
        u.upvoted_roll.class.should == Roll
        u.upvoted_roll.persisted?.should == true
        
        u.viewed_roll.class.should == Roll
        u.viewed_roll.persisted?.should == true
      }.should change { User.count }.by(1)
    end
    
    it "should set the faux user's public_roll's thumbnail and network to those of the creator" do
      thumb_url = "some://thumb.url"
      nick, provider, uid = "whatever3--c", "fb", "123uid3--c"
      u = GT::UserManager.get_or_create_faux_user(nick, provider, uid, {:user_thumbnail_url => thumb_url})
      
      u.public_roll.creator_thumbnail_url.should == thumb_url
      u.public_roll.origin_network.should == "fb"
    end
    
    it "should have the faux user follow its own public, upvoted and watch_later rolls (should not follow viewed rolls)" do
      nick, provider, uid = "whatever3-c", "fb", "123uid3-c"
      lambda {
        u = GT::UserManager.get_or_create_faux_user(nick, provider, uid)
        
        u.following_roll?(u.public_roll).should == true
        u.following_roll?(u.upvoted_roll).should == true
        u.following_roll?(u.watch_later_roll).should == true
        
        u.following_roll?(u.viewed_roll).should == false
      }.should change { User.count }.by(1)
    end
    
    it "should have (persisted) public, watch_later, upvoted, viwed Rolls on the User it creates" do
      nick, provider, uid = "whatever4", "fb", "123uid4"

      u = GT::UserManager.get_or_create_faux_user(nick, provider, uid)
      #Public
      r = u.public_roll
      r.class.should == Roll
      r.persisted?.should == true
      r.public.should == true
      r.collaborative.should == false
      r.creator.should == u
      r.roll_type.should == Roll::TYPES[:special_public]
      
      #watch later
      r = u.watch_later_roll
      r.class.should == Roll
      r.persisted?.should == true
      r.public.should == false
      r.collaborative.should == false
      r.creator.should == u
      r.roll_type.should == Roll::TYPES[:special_watch_later]
      
      #upvoted
      r = u.upvoted_roll
      r.class.should == Roll
      r.persisted?.should == true
      r.public.should == true
      r.collaborative.should == false
      r.upvoted_roll.should == true
      r.creator.should == u
      r.roll_type.should == Roll::TYPES[:special_upvoted]
      
      #viewed
      r = u.viewed_roll
      r.class.should == Roll
      r.persisted?.should == true
      r.public.should == false
      r.collaborative.should == false
      r.creator.should == u
      r.roll_type.should == Roll::TYPES[:special_viewed]
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
    
    it "should update user's image if it's null" do
      nick, provider, uid = "whatever-x1", "fb", "123uid-x1"
      u = User.new(:nickname => nick)
      u.faux = User::FAUX_STATUS[:true]
      u.downcase_nickname = nick
      auth = Authentication.new
      auth.provider = provider
      auth.uid = uid
      u.authentications << auth
      u.save
      
      u.persisted?.should == true
      
      u = GT::UserManager.get_or_create_faux_user(nick, provider, uid, :user_thumbnail_url => "someURL")
      u.user_image.should == "someURL"
      u.user_image_original.should == "someURL"
      
      #should not change it next time around
      u = GT::UserManager.get_or_create_faux_user(nick, provider, uid, :user_thumbnail_url => "new_URL")
      u.user_image.should == "someURL"
      u.user_image_original.should == "someURL"
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
      
      it "should convert all sorts of funky nicknames to something acceptable" do
        #commas
        nick, provider, uid = "Nature, Love and Art", "fb", 123
        GT::UserManager.get_or_create_faux_user(nick, provider, (uid+=1).to_s).nickname.should == "Nature__Love_and_Art"

        #tildes
        nick = "~weird"
        GT::UserManager.get_or_create_faux_user(nick, provider, (uid+=1).to_s).nickname.should == "_weird"

        #only junk
        nick = "~,':&"
        GT::UserManager.get_or_create_faux_user(nick, provider, (uid+=1).to_s).nickname.should == "____"

        #unnaceptable characters
        nick = "ヅللمسلمين فقط ! بالله عليك إذا كنت مسلم و رأيت هذه الصفحة أدخل إليها๑۞๑"
        GT::UserManager.get_or_create_faux_user(nick, provider, (uid+=1).to_s).nickname.should == "ヅللمسلمين_فقط__بالله_عليك_إذا_كنت_مسلم_و_رأيت_هذه_الصفحة_أدخل_إليها๑۞๑"
        
        #only unnaceptable characters
        nick = "Անվանագիրք"
        GT::UserManager.get_or_create_faux_user(nick, provider, (uid+=1).to_s).nickname.should == "cobra"
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
      # we sleep when finding a new user, need to stub that
      EventMachine::Synchrony.stub(:sleep)
      
      @omniauth_hash = {
        'provider' => "twitter",
        'uid' => rand.to_s,
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
      
      @faux_u = Factory.create(:user, :gt_enabled => false, :faux => User::FAUX_STATUS[:true], :app_progress => AppProgress.new)
      GT::UserManager.ensure_users_special_rolls(@faux_u, true)
    end
    
    it "should convert a (persisted) faux User to real user" do
      real_u, new_auth = GT::UserManager.convert_faux_user_to_real(@faux_u, @omniauth_hash)
      real_u.class.should == User
      real_u.persisted?.should == true
      real_u.faux.should == User::FAUX_STATUS[:converted]
    end
    
    it "should convert a (persisted) faux User to real user w/o omniauth creds" do
      real_u, new_auth = GT::UserManager.convert_faux_user_to_real(@faux_u)
      real_u.class.should == User
      real_u.persisted?.should == true
      real_u.faux.should == User::FAUX_STATUS[:converted]
      new_auth.should == nil
    end
    
    it "should update their public roll's roll_type" do
      @faux_u.public_roll.roll_type.should == Roll::TYPES[:special_public]
      GT::UserManager.convert_faux_user_to_real(@faux_u)
      @faux_u.public_roll.roll_type.should == Roll::TYPES[:special_public_real_user]
    end
    
    it "should follow their watch_later roll if they're not" do
      @faux_u.watch_later_roll.remove_follower(@faux_u)
      @faux_u.reload.following_roll?(@faux_u.watch_later_roll.reload).should == false
      
      GT::UserManager.convert_faux_user_to_real(@faux_u)
      @faux_u.reload.following_roll?(@faux_u.watch_later_roll.reload).should == true
      
    end
    
    it "should make their watch_later roll private if it's not" do
      @faux_u.watch_later_roll.update_attribute(:public, true)
      @faux_u.watch_later_roll.reload.public.should == true
      
      GT::UserManager.convert_faux_user_to_real(@faux_u)
      
      @faux_u.watch_later_roll.reload.public.should == false
    end
    
    it "should make their upvoted_roll roll public if it's not" do
      @faux_u.upvoted_roll.update_attribute(:public, false)
      @faux_u.upvoted_roll.reload.public.should == false
      
      GT::UserManager.convert_faux_user_to_real(@faux_u)
      
      @faux_u.upvoted_roll.reload.public.should == true
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
    
    it "should have app_progrss set" do
      real_u, new_auth = GT::UserManager.convert_faux_user_to_real(@faux_u, @omniauth_hash)
      real_u.app_progress.class.should eq(AppProgress)
    end
    
    it "should have at least one cohort" do
      real_u, new_auth = GT::UserManager.convert_faux_user_to_real(@faux_u, @omniauth_hash)
      real_u.cohorts.size.should > 0
    end
    
    it "should follow all twitter and facebook friends" do
      GT::UserTwitterManager.should_receive(:follow_all_friends_public_rolls).exactly(1).times
      GT::UserFacebookManager.should_receive(:follow_all_friends_public_rolls).exactly(1).times
      real_u, new_auth = GT::UserManager.convert_faux_user_to_real(@faux_u, @omniauth_hash)
    end
  end
  
  context "create_user" do
    
    context "from omniauth" do
      before(:each) do
        @nickname = "nick-#{rand.to_s}"
        @omniauth_hash = {
          'provider' => "twitter",
          'uid' => "#{rand.to_s}-#{Time.now.to_f}",
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
        u.valid?.should == true
        u.gt_enabled?.should == true
        u.cohorts.size.should > 0
        u.nickname.should eq(@nickname)
        u.user_image.should == @omniauth_hash['info']['image']
      end
      
      it "should change nickname if it's taken" do
        current_user = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash)
        @omniauth_hash['uid'] += "2"
        GT::UserManager.create_new_user_from_omniauth(@omniauth_hash).nickname.should_not == current_user.nickname
      end
      
      it "should replace whitespace in the nickname with underscore" do
        @omniauth_hash["info"]["nickname"] = "dan spinosa"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash)
        u.valid?.should eql(true)
        u.nickname.should eql("dan_spinosa")

        @omniauth_hash['uid'] += "2"
        @omniauth_hash["info"]["nickname"] = " spinosa"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash)
        u.valid?.should eql(true)
        u.nickname.should eql("_spinosa")

        @omniauth_hash['uid'] += "2"
        @omniauth_hash["info"]["nickname"] = "spinosa "
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash)
        u.valid?.should eql(true)
        u.nickname.should eql("spinosa_")

        @omniauth_hash['uid'] += "2"
        @omniauth_hash["info"]["nickname"] = "spinDr"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash)
        u.valid?.should eql(true)
      end
      
      it "should remove invalid punctuation from nickname" do
        @omniauth_hash["info"]["nickname"] = "dan‘s’"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash)
        u.valid?.should == true
        u.nickname.should == "dans"

        @omniauth_hash['uid'] += "2"
        @omniauth_hash["info"]["nickname"] = "'Astrid_Carolina_Valdez"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash)
        u.valid?.should == true
        u.nickname.should == "Astrid_Carolina_Valdez"
      end
      
      it "should validate nickname w/ utf8 support, dot, underscore and/or hyphen" do
        @omniauth_hash['uid'] += "2"
        @omniauth_hash['info']['nickname'] = "J.Marie_Teis-Sèdre"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash).should_not == nil
        
        @omniauth_hash['uid'] += "2"
        @omniauth_hash['info']['nickname'] = "보통그냥"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash).should_not == nil
        
        @omniauth_hash['uid'] += "2"
        @omniauth_hash['info']['nickname'] = "Boris Šebošík"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash).should_not == nil
        
        @omniauth_hash['uid'] += "2"
        @omniauth_hash['info']['nickname'] = "Олег_Бородин"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash).should_not == nil
        
        @omniauth_hash['uid'] += "2"
        @omniauth_hash['info']['nickname'] = "Станислав_Станислав"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash).should_not == nil
        
        @omniauth_hash['uid'] += "2"
        @omniauth_hash['info']['nickname'] = "厚任_賴厚任"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash).should_not == nil
        
        @omniauth_hash['uid'] += "2"
        @omniauth_hash['info']['nickname'] = "Thập_Lục_Thập"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash).should_not == nil
        
        @omniauth_hash['uid'] += "2"
        @omniauth_hash['info']['nickname'] = "ธีระพงษ์_อารีเอื้อ"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash).should_not == nil
        
        @omniauth_hash['uid'] += "2"
        @omniauth_hash['info']['nickname'] = "鎮順_陳鎮順"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash).should_not == nil
        
        @omniauth_hash['uid'] += "2"
        @omniauth_hash['info']['nickname'] = "Андрей_Бабакاسي"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash).should_not == nil
        
        @omniauth_hash['uid'] += "2"
        @omniauth_hash['info']['nickname'] = "ابراهي_اليم"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash).should_not == nil
        
        @omniauth_hash['uid'] += "2"
        @omniauth_hash['info']['nickname'] = "Παναγής_Μέγαρα"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash).should_not == nil
        
        @omniauth_hash['uid'] += "2"
        @omniauth_hash['info']['nickname'] = "அன்புடன்_ஆனந்தகுமார்"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash).should_not == nil
        
        @omniauth_hash['uid'] += "2"
        @omniauth_hash['info']['nickname'] = "אבו_ודיע"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash).should_not == nil
        
        @omniauth_hash['uid'] += "2"
        @omniauth_hash['info']['nickname'] = "ომარი_დევიძე"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash).should_not == nil
        
        @omniauth_hash['uid'] += "2"
        @omniauth_hash['info']['nickname'] = "みさお_みさお"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash).should_not == nil
        
        @omniauth_hash['uid'] += "2"
        @omniauth_hash['info']['nickname'] = "たくや_たくや"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash).should_not == nil
        
        @omniauth_hash['uid'] += "2"
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

        @omniauth_hash['uid'] += "2"
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
        u.preferences.open_graph_posting.should == nil
      end

      it "should always have app_progress once created" do
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash)
        u.app_progress.class.should eq(AppProgress)
      end
      
      it "should create and persist public, watch_later, upvoted, viwed Rolls for new User" do
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash)
        
        u.public_roll.class.should == Roll
        u.public_roll.persisted?.should == true
        u.public_roll.reload.roll_type.should == Roll::TYPES[:special_public_real_user]
        
        u.watch_later_roll.class.should == Roll
        u.watch_later_roll.persisted?.should == true
        
        u.upvoted_roll.class.should == Roll
        u.upvoted_roll.upvoted_roll.should == true
        u.upvoted_roll.persisted?.should == true
        
        u.viewed_roll.class.should == Roll
        u.viewed_roll.persisted?.should == true
      end
      
      it "should set the public_roll's thumbnail to the creator's avatar" do
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash)
        
        u.public_roll.creator_thumbnail_url.should == @omniauth_hash['info']['image']
      end
      
      it "should set the origin_network on the user's public roll" do
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash)
        
        u.public_roll.origin_network.should == Roll::SHELBY_USER_PUBLIC_ROLL
      end
      
      it "should have the user follow their public, upvoted, and watch_later rolls (and NOT the viewed Roll)" do
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash)
        
        u.following_roll?(u.public_roll).should == true
        u.following_roll?(u.upvoted_roll).should == true
        u.following_roll?(u.watch_later_roll).should == true
        u.following_roll?(u.viewed_roll).should == false
      end
      
      it "should follow all twitter and facebook friends" do
        GT::UserTwitterManager.should_receive(:follow_all_friends_public_rolls).exactly(1).times
        GT::UserFacebookManager.should_receive(:follow_all_friends_public_rolls).exactly(1).times
        current_user = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash)
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
    
    context "from params (ie. email/password)" do
      before(:each) do
        @params = {:nickname => Factory.next(:nickname), :primary_email => Factory.next(:primary_email), :password => "password", :name => "name"}
      end
      
      it "should create a valid user itself from params" do
        lambda {
          u = GT::UserManager.create_new_user_from_params(@params)
          u.valid?.should == true
          u.persisted?.should == true
          u.gt_enabled?.should == true
          u.cohorts.size.should > 0
          u.nickname.should == @params[:nickname]
        }.should change { User.count } .by(1)
      end
      
      it "should change nickname and still create user if it's taken" do
        lambda {
          u1 = GT::UserManager.create_new_user_from_params(@params)
          @params[:primary_email] = Factory.next(:primary_email)
          u2 = GT::UserManager.create_new_user_from_params(@params)
          u2.valid?.should == true
          u2.persisted?.should == true
          u2.nickname.should_not == @params[:nickname]
        }.should change { User.count } .by(2)
      end
      
      it "should fail and return error if email is taken" do
        lambda {
          u1 = GT::UserManager.create_new_user_from_params(@params)
          @params[:nickname] = Factory.next :nickname
          u1 = GT::UserManager.create_new_user_from_params(@params)
          u1.valid?.should == false
          u1.errors.should be_a ActiveModel::Errors
          u1.errors.messages.include?(:primary_email).should == true
        }.should change { User.count } .by(1)
      end
      
      it "should create and persist public, watch_later, upvoted, viwed Rolls for new User" do
        u = GT::UserManager.create_new_user_from_params(@params)
        
        u.public_roll.class.should == Roll
        u.public_roll.persisted?.should == true
        
        u.watch_later_roll.class.should == Roll
        u.watch_later_roll.persisted?.should == true
        
        u.upvoted_roll.class.should == Roll
        u.upvoted_roll.upvoted_roll.should == true
        u.upvoted_roll.persisted?.should == true
        
        u.viewed_roll.class.should == Roll
        u.viewed_roll.persisted?.should == true
      end
      
    end
    
  end
  
  context "update user" do
    before(:each) do
      @nickname = "nick-#{rand.to_s}"
      @omniauth_hash = {
        'provider' => "twitter",
        'uid' => "#{rand.to_s}-#{Time.now.to_f}",
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
    
    it "should be able to update auth tokens via omniauth" do
      u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash)
      
      # UPDATE
      @omniauth_hash['credentials']['token'] = "NEW--token"
      @omniauth_hash['credentials']['secret'] = "NEW--secret"
      
      GT::UserManager.start_user_sign_in(u, :omniauth => @omniauth_hash)

      auth = GT::AuthenticationBuilder.authentication_by_provider_and_uid(u, "twitter", @omniauth_hash['uid'] )
      auth.should_not == nil
      auth.provider.should == "twitter"
      auth.uid.should == @omniauth_hash['uid']
      auth.oauth_token.should == "NEW--token"
      auth.oauth_secret.should == "NEW--secret"
    end
    
    context "autocomplete" do

      context "signin existing user" do
        before(:each) do
          @u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash)
        end

        it "should retrieve and save twitter autocomplete info on signin of existing user" do
            @twt_info_getter.should_receive(:get_following_screen_names)
            @u.should_receive(:store_autocomplete_info).with(:twitter,['a','b'])
            GT::UserManager.start_user_sign_in(@u, :omniauth => @omniauth_hash)
        end

        it "should not save twitter autocomplete info if TwitterError occurs" do
            @twt_info_getter.should_receive(:get_following_screen_names).and_raise(Grackle::TwitterError.new('', '', '', ''))
            @u.should_not_receive(:store_autocomplete_info)
            GT::UserManager.start_user_sign_in(@u, :omniauth => @omniauth_hash)
        end

        it "should not save twitter autocomplete info if the user doesn't have twitter auth" do
            omniauth = @omniauth_hash.clone()
            omniauth['provider'] = 'facebook'
            u = GT::UserManager.create_new_user_from_omniauth(omniauth)
            @twt_info_getter.should_not_receive(:get_following_screen_names)
            GT::UserManager.start_user_sign_in(u, :omniauth => omniauth)
        end
      end

      context "create new user via omniauth" do
        it "should retrieve and save twitter autocomplete info on creation of new user via omniauth" do
            @twt_info_getter.should_receive(:get_following_screen_names)
            u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash)
        end
      end
    end

    it "should be able to update auth tokens via direct options" do
      u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash)
      
      # UPDATE is inline
      GT::UserManager.start_user_sign_in(u, 
        :provider => @omniauth_hash['provider'],
        :uid => @omniauth_hash['uid'],
        :token => "NEW--token",
        :secret => "NEW--secret")

      auth = GT::AuthenticationBuilder.authentication_by_provider_and_uid(u, "twitter", @omniauth_hash['uid'] )
      auth.should_not == nil
      auth.provider.should == "twitter"
      auth.uid.should == @omniauth_hash['uid']
      auth.oauth_token.should == "NEW--token"
      auth.oauth_secret.should == "NEW--secret"
    end

    it "should create app_progress if it doesnt exist" do
      u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash)
      u.app_progress = nil; u.save
      GT::UserManager.start_user_sign_in(u, :omniauth => @omniauth_hash)
      u.app_progress.class.should eq(AppProgress)
    end
    
    it "should be able to start user signin without omniauth" do
      u = Factory.create(:user)
      GT::UserManager.start_user_sign_in(u)
      u.app_progress.class.should eq(AppProgress)
    end
    
    context "adding new auth" do
      before(:each) do
        @nickname = "nick-#{rand.to_s}"
        @new_omniauth_hash = {
          'provider' => "facebook",
          'uid' => "#{rand.to_s}-#{Time.now.to_f}",
          'credentials' => {
            'token' => "somelongtoken",
            'secret' => 'foreskin',
            'garbage' => 'truck'
          },
          'info' => {
            'name' => 'some name',
            'nickname' => @nickname,
            'garbage' => 'truck'
          },
          'garbage' => 'truck'
        }
      end
      
      it "should add a new auth to an existing user" do
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash)
        
        updated_u = GT::UserManager.add_new_auth_from_omniauth(u, @new_omniauth_hash)
        u.id.should == updated_u.id
      end
      
      it "should follow all twitter and facebook friends when adding a twitter auth" do
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash)
        
        @new_omniauth_hash['provider'] = "twitter"
        
        GT::UserTwitterManager.should_receive(:follow_all_friends_public_rolls).exactly(1).times
        GT::UserFacebookManager.should_receive(:follow_all_friends_public_rolls).exactly(1).times
        updated_u = GT::UserManager.add_new_auth_from_omniauth(u, @new_omniauth_hash)
      end
    
      it "should follow all twitter and facebook friends when adding a facebook auth" do
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash)
        
        @new_omniauth_hash['provider'] = "facebook"
        
        GT::UserTwitterManager.should_receive(:follow_all_friends_public_rolls).exactly(1).times
        GT::UserFacebookManager.should_receive(:follow_all_friends_public_rolls).exactly(1).times
        updated_u = GT::UserManager.add_new_auth_from_omniauth(u, @new_omniauth_hash)
      end
    end
  end
  
  context "verify user" do
    before(:each) do
      @user = Factory.create(:user) #adds a twitter authentication
      @twt_auth = @user.authentications[0]
      @fb_auth = Factory.create(:authentication, :provider => "facebook", :oauth_secret => nil)
      @user.authentications << @fb_auth
      @user.save
    end

    it "should fail if it can't find auth" do
      GT::UserManager.verify_user(@user, "fake_provider", "fake_uid", "fake_token").should == false
    end
  
    it "should verify w/ twitter externally if token/secret don't match" do
      token = "fake_token"
      secret = "fake_secret"
      GT::UserTwitterManager.should_receive(:verify_auth).with(token, secret).and_return(true)
          
      GT::UserManager.verify_user(@user, "twitter", @twt_auth.uid, token, secret).should == true
    end
  
    it "should verify w/ twitter internally if token/secret do match" do
      GT::UserTwitterManager.should_receive(:verify_auth).exactly(0).times
          
      GT::UserManager.verify_user(@user, "twitter", @twt_auth.uid, @twt_auth.oauth_token, @twt_auth.oauth_secret).should == true
    end
  
    it "should verify w/ FB externally if token/secret don't match" do
      token = "fake_token"
      GT::UserFacebookManager.should_receive(:verify_auth).with(token).and_return(true)
          
      GT::UserManager.verify_user(@user, "facebook", @fb_auth.uid, token).should == true
    end
  
    it "should verify w/ FB internally if token/secret do match" do
      GT::UserFacebookManager.should_receive(:verify_auth).exactly(0).times
          
      GT::UserManager.verify_user(@user, "facebook", @fb_auth.uid, @fb_auth.oauth_token).should == true
    end
  
    it "should not verify and return false if user does not have that auth" do
      GT::UserManager.verify_user(@user, "something_DNE", "some_id", "token", "secret").should == false
    end    
  end
  
  context "cohort copying" do
    it "should copy all cohorts from inviter to user with no additional cohorts" do
      c = ["a", "b", "c"]
      u1 = Factory.create(:user, :cohorts => c)
      u2 = Factory.create(:user)
      
      GT::UserManager.copy_cohorts!(u1, u2)
      
      u2.reload.cohorts.should == c
      u1.reload.cohorts.should == c
    end
    
    it "should copy zero cohorts from inviter to user with no additional cohorts" do
      u1 = Factory.create(:user)
      u2 = Factory.create(:user)
      
      GT::UserManager.copy_cohorts!(u1, u2)
      
      u2.reload.cohorts.should == []
      u1.reload.cohorts.should == []
    end
    
    it "should copy all cohorts from inviter to user with additional cohorts" do
      c = ["a", "b", "c"]
      addtl = ["x", "y"]
      u1 = Factory.create(:user, :cohorts => c)
      u2 = Factory.create(:user)
      
      GT::UserManager.copy_cohorts!(u1, u2, addtl)

      u2.reload.cohorts.should == c + addtl
      u1.reload.cohorts.should == c
    end
    
    it "shouldnt fuck with original cohorts of to user" do
      c = ["a", "b", "c"]
      addtl = ["x", "y"]
      to_orig_cohorts = ["o"]
      u1 = Factory.create(:user, :cohorts => c)
      u2 = Factory.create(:user, :cohorts => to_orig_cohorts)
      
      GT::UserManager.copy_cohorts!(u1, u2, addtl)

      u2.reload.cohorts.should == to_orig_cohorts + c + addtl
      u1.reload.cohorts.should == c
    end
  end
  
  context "helper stuff" do
    it "should add public and watch later roll w/o saving" do
      u = Factory.create(:user)
      u.public_roll.should == nil
      u.watch_later_roll.should == nil
      GT::UserManager.ensure_users_special_rolls(u)
      u.public_roll.class.should == Roll
      u.watch_later_roll.class.should == Roll
    end
    
    it "should add public and watch later roll and save" do
      u = Factory.create(:user)
      u.public_roll.should == nil
      u.watch_later_roll.should == nil
      GT::UserManager.ensure_users_special_rolls(u, true)
      u.public_roll.persisted?.should == true
      u.watch_later_roll.persisted?.should == true
    end
    
  end
  
end
  
