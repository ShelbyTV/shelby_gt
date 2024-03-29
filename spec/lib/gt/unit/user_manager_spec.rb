# encoding: UTF-8

require 'spec_helper'

require 'user_manager'
require 'authentication_builder'
require 'predator_manager'
require 'api_clients/sailthru_client'

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
      u.user_type = User::USER_TYPE[:faux]
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
      u.user_type = User::USER_TYPE[:faux]
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
      u.user_type = User::USER_TYPE[:faux]
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
        usr.public_roll.roll_type.should == Roll::TYPES[:special_public]
      }.should_not change { User.count }
    end

    it "should add a watch_later_roll, upvoted_roll, viewed_roll, public_roll to existing user if they're missing it" do
      nick, provider, uid = "whatever--b-", "fb--", "123uid--b-"
      thumb_url = "some://thumb.url"
      u = User.new(:nickname => nick)
      u.user_type = User::USER_TYPE[:faux]
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
        u.user_type.should == User::USER_TYPE[:faux]
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
      }.should_not raise_error
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
      }.should_not raise_error
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
      u.user_type = User::USER_TYPE[:faux]
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
        GT::UserManager.get_or_create_faux_user(nick, provider, uid).nickname.should == "whatever-6"
      end

      it "should remove quote marks" do
        nick, provider, uid = "whatever'‘’\"`7", "fb", "123uid7"
        GT::UserManager.get_or_create_faux_user(nick, provider, uid).nickname.should == "whatever7"
      end

      it "should make the nickname unique" do
        nick, provider, uid = "whatever 6", "fb", "123uid8"
        GT::UserManager.get_or_create_faux_user(nick, provider, uid).nickname.should_not == "whatever-6"

        nick, provider, uid = "whatever 6", "fb", "123uid82"
        GT::UserManager.get_or_create_faux_user(nick, provider, uid).nickname.should_not == "whatever-6"
      end

      it "should convert all sorts of funky nicknames to something acceptable" do
        #commas
        nick, provider, uid = "Nature, Love and Art", "fb", 123
        GT::UserManager.get_or_create_faux_user(nick, provider, (uid+=1).to_s).nickname.should == "Nature--Love-and-Art"

        #tildes
        nick = "~weird"
        GT::UserManager.get_or_create_faux_user(nick, provider, (uid+=1).to_s).nickname.should == "-weird"

        #only junk
        nick = "~,':&"
        GT::UserManager.get_or_create_faux_user(nick, provider, (uid+=1).to_s).nickname.should == "----"

        #unnaceptable characters
        nick = "ヅللمسلمين فقط ! بالله عليك إذا كنت مسلم و رأيت هذه الصفحة أدخل إليها๑۞๑"
        GT::UserManager.get_or_create_faux_user(nick, provider, (uid+=1).to_s).nickname.should == "ヅللمسلمين-فقط--بالله-عليك-إذا-كنت-مسلم-و-رأيت-هذه-الصفحة-أدخل-إليها๑۞๑"

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

  context "convert_eligible_user_to_real" do
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
          'image' => "http://original.com/image_normal.png",
          'garbage' => 'truck'
        },
        'garbage' => 'truck'
      }

      @faux_u = Factory.create(:user, :gt_enabled => false, :user_type => User::USER_TYPE[:faux], :app_progress => AppProgress.new)
      GT::UserManager.ensure_users_special_rolls(@faux_u, true)
    end

    it "should convert a (persisted) faux User to real user" do
      real_u, new_auth = GT::UserManager.convert_eligible_user_to_real(@faux_u, @omniauth_hash)
      real_u.class.should == User
      real_u.persisted?.should == true
      real_u.user_type.should == User::USER_TYPE[:converted]
    end

    it "should convert a (persisted) faux User to real user w/o omniauth creds" do
      real_u, new_auth = GT::UserManager.convert_eligible_user_to_real(@faux_u)
      real_u.class.should == User
      real_u.persisted?.should == true
      real_u.user_type.should == User::USER_TYPE[:converted]
      new_auth.should == nil
    end

    it "converts a (persisted) anonymous User with an email and password to real user w/o omniauth creds" do
      anonymous_u_public_roll = Factory.create(:roll, :roll_type => Roll::TYPES[:special_public])
      anonymous_u = Factory.create(
        :user,
        :public_roll => anonymous_u_public_roll,
        :user_type => User::USER_TYPE[:anonymous],
        :authentications => []
      )
      real_u, new_auth = GT::UserManager.convert_eligible_user_to_real(anonymous_u)
      real_u.class.should == User
      real_u.persisted?.should == true
      real_u.user_type.should == User::USER_TYPE[:converted]
      new_auth.should == nil
      MongoMapper::Plugins::IdentityMap.clear
      Roll.find(anonymous_u_public_roll.id).roll_type.should == Roll::TYPES[:special_public_real_user]
    end

    it "converts a (persisted) anonymous User with an existing authentication to real user w/o omniauth creds" do
      anonymous_u_public_roll = Factory.create(:roll, :roll_type => Roll::TYPES[:special_public])
      anonymous_u = Factory.create(
        :user,
        :public_roll => anonymous_u_public_roll,
        :user_type => User::USER_TYPE[:anonymous],
        :primary_email => nil,
        :authentications => [{}]
      )
      real_u, new_auth = GT::UserManager.convert_eligible_user_to_real(anonymous_u)
      real_u.class.should == User
      real_u.persisted?.should == true
      real_u.user_type.should == User::USER_TYPE[:converted]
      new_auth.should == nil
      MongoMapper::Plugins::IdentityMap.clear
      Roll.find(anonymous_u_public_roll.id).roll_type.should == Roll::TYPES[:special_public_real_user]
    end

    it "doesn't do anything the second time if called twice on the same user" do
      anonymous_u_public_roll = Factory.create(:roll)
      anonymous_u = Factory.create(
        :user,
        :public_roll => anonymous_u_public_roll,
        :user_type => User::USER_TYPE[:anonymous],
        :authentications => []
      )

      expect(GT::UserManager.convert_eligible_user_to_real(anonymous_u)).not_to be_nil
      expect(GT::UserManager.convert_eligible_user_to_real(anonymous_u)).to be_nil
    end

    it "should update their public roll's roll_type" do
      @faux_u.public_roll.roll_type.should == Roll::TYPES[:special_public]
      GT::UserManager.convert_eligible_user_to_real(@faux_u)
      MongoMapper::Plugins::IdentityMap.clear
      Roll.find(@faux_u.public_roll.id).roll_type.should == Roll::TYPES[:special_public_real_user]
    end

    it "should follow their watch_later roll if they're not" do
      @faux_u.watch_later_roll.remove_follower(@faux_u)
      @faux_u.reload.following_roll?(@faux_u.watch_later_roll.reload).should == false

      GT::UserManager.convert_eligible_user_to_real(@faux_u)
      @faux_u.reload.following_roll?(@faux_u.watch_later_roll.reload).should == true

    end

    it "should make their watch_later roll private if it's not" do
      @faux_u.watch_later_roll.update_attribute(:public, true)
      @faux_u.watch_later_roll.reload.public.should == true

      GT::UserManager.convert_eligible_user_to_real(@faux_u)

      @faux_u.watch_later_roll.reload.public.should == false
    end

    it "should make their upvoted_roll roll public if it's not" do
      @faux_u.upvoted_roll.update_attribute(:public, false)
      @faux_u.upvoted_roll.reload.public.should == false

      GT::UserManager.convert_eligible_user_to_real(@faux_u)

      @faux_u.upvoted_roll.reload.public.should == true
    end

    it "should have one authentication with an oauth token" do
      real_u, new_auth = GT::UserManager.convert_eligible_user_to_real(@faux_u, @omniauth_hash)
      real_u.authentications.length.should eq(1)
      new_auth.oauth_token.should eq(@omniauth_hash["credentials"]["token"])
    end

    it "should have preferences set" do
      real_u, new_auth = GT::UserManager.convert_eligible_user_to_real(@faux_u, @omniauth_hash)
      real_u.preferences.class.should eq(Preferences)
    end

    it "should have app_progrss set" do
      real_u, new_auth = GT::UserManager.convert_eligible_user_to_real(@faux_u, @omniauth_hash)
      real_u.app_progress.class.should eq(AppProgress)
    end

    it "should have at least one cohort" do
      real_u, new_auth = GT::UserManager.convert_eligible_user_to_real(@faux_u, @omniauth_hash)
      real_u.cohorts.size.should > 0
    end

    it "should follow all twitter and facebook friends" do
      GT::UserTwitterManager.should_receive(:follow_all_friends_public_rolls).exactly(1).times
      GT::UserFacebookManager.should_receive(:follow_all_friends_public_rolls).exactly(1).times
      real_u, new_auth = GT::UserManager.convert_eligible_user_to_real(@faux_u, @omniauth_hash)
    end

    it "does nothing and returns nil if the user is already real" do
      real_user = Factory.create(:user, :user_type => User::USER_TYPE[:real])
      expect(GT::UserManager.convert_eligible_user_to_real(real_user)).to be_nil

      converted_user = Factory.create(:user, :user_type => User::USER_TYPE[:converted])
      expect(GT::UserManager.convert_eligible_user_to_real(converted_user)).to be_nil

      service_user = Factory.create(:user, :user_type => User::USER_TYPE[:service])
      expect(GT::UserManager.convert_eligible_user_to_real(service_user)).to be_nil
    end

    it "does nothing and returns nil if the user is anonymous and hasn't met the criteria for conversion yet" do
      anonymous_user = Factory.create(:user, :user_type => User::USER_TYPE[:service])
      anonymous_user.authentications = []
      anonymous_user.primary_email = nil

      expect(GT::UserManager.convert_eligible_user_to_real(anonymous_user)).to be_nil
    end
  end

  context "convert_real_user_to_faux" do
    before(:each) do
      @public_roll = Factory.create(:roll, :roll_type => Roll::TYPES[:special_public_real_user])
      @real_user = Factory.create(:user, :user_type => User::USER_TYPE[:real], :public_roll => @public_roll, :gt_enabled => false)
    end

    it "should raise an error when given a non-real user" do
      @real_user.user_type = User::USER_TYPE[:faux]
      lambda {
        GT::UserManager.convert_real_user_to_faux(@real_user)
      }.should raise_error(ArgumentError)
    end

    it "should not raise an error when given a gt enabled user" do
      @real_user.gt_enabled = true
      lambda {
        GT::UserManager.convert_real_user_to_faux(@real_user)
      }.should_not raise_error
    end

    it "should change the user type to faux" do
      GT::UserManager.convert_real_user_to_faux(@real_user)
      @real_user.user_type.should eq User::USER_TYPE[:faux]
    end

    it "should reset the preferences" do
      lambda {
        GT::UserManager.convert_real_user_to_faux(@real_user)
      }.should change { @real_user.preferences }
    end

    it "should reset the app progress" do
      lambda {
        GT::UserManager.convert_real_user_to_faux(@real_user)
      }.should change { @real_user.app_progress}
    end

    it "should clear the primary email and move the old primary email to the key nos_email" do
      old_primary_email = @real_user.primary_email

      GT::UserManager.convert_real_user_to_faux(@real_user)

      @real_user.primary_email.should be_nil
      @real_user.nos_email.should eql old_primary_email
    end

    it "should save the changes to the user" do
      GT::UserManager.convert_real_user_to_faux(@real_user)

      #use ActiveRecord changed? to verify that the object is not dirty
      @real_user.should_not be_changed
    end

    it "should update the type of the user's public roll and save it" do
      GT::UserManager.convert_real_user_to_faux(@real_user)

      @public_roll.roll_type.should eql Roll::TYPES[:special_public]
      #use ActiveRecord changed? to verify that the roll object is not dirty
      @public_roll.should_not be_changed
    end

  end

  context "fix_user_public_roll_type" do

    it "should correct the roll type for a faux user" do
      public_roll = Factory.create(:roll, :roll_type => Roll::TYPES[:special_public_real_user])
      faux_user = Factory.create(:user, :user_type => User::USER_TYPE[:faux], :public_roll => public_roll)

      GT::UserManager.fix_user_public_roll_type(faux_user).should == true

      faux_user.public_roll.roll_type.should eql Roll::TYPES[:special_public]
      #use ActiveRecord changed? to verify that the roll object is not dirty
      faux_user.public_roll.should_not be_changed

      # calling it on a user that's already fixed should return false
      GT::UserManager.fix_user_public_roll_type(faux_user).should == false
    end

    it "corrects the roll type for a real user" do
      public_roll = Factory.create(:roll, :roll_type => Roll::TYPES[:special_public])
      real_user = Factory.create(:user, :user_type => User::USER_TYPE[:real], :public_roll => public_roll)

      GT::UserManager.fix_user_public_roll_type(real_user).should == true

      real_user.public_roll.roll_type.should eql Roll::TYPES[:special_public_real_user]
      #use ActiveRecord changed? to verify that the roll object is not dirty
      real_user.public_roll.should_not be_changed

      # calling it on a user that's already fixed should return false
      GT::UserManager.fix_user_public_roll_type(real_user).should == false
    end

    it "corrects the roll type for a converted user" do
      public_roll = Factory.create(:roll, :roll_type => Roll::TYPES[:special_public])
      converted_user = Factory.create(:user, :user_type => User::USER_TYPE[:converted], :public_roll => public_roll)

      GT::UserManager.fix_user_public_roll_type(converted_user).should == true

      converted_user.public_roll.roll_type.should eql Roll::TYPES[:special_public_real_user]
      #use ActiveRecord changed? to verify that the roll object is not dirty
      converted_user.public_roll.should_not be_changed

      # calling it on a user that's already fixed should return false
      GT::UserManager.fix_user_public_roll_type(converted_user).should == false
    end

    it "should do nothing if the user type and user public roll type already match" do
      public_roll = Factory.create(:roll, :roll_type => Roll::TYPES[:special_public])
      faux_user = Factory.create(:user, :user_type => User::USER_TYPE[:faux], :public_roll => public_roll)
      faux_user.public_roll.should_not_receive(:save)

      GT::UserManager.fix_user_public_roll_type(faux_user).should == false

      #faux users have two acceptable roll types
      public_roll.roll_type = Roll::TYPES[:special_public_upgraded]
      GT::UserManager.fix_user_public_roll_type(faux_user).should == false
    end

  end

  context "update_app_progress_onboarding" do
    before(:each) do
      @user_to_update = Factory.create(:user, :app_progress => AppProgress.new)
    end

    it "should create an app progress model if there is none" do
      @user_to_update.should_receive(:save).once.and_call_original

      @user_to_update.app_progress = nil

      GT::UserManager.update_app_progress_onboarding(@user_to_update)
      @user_to_update.app_progress.onboarding.should eql false
    end

    it "should make nil values false" do
      @user_to_update.should_receive(:save).and_call_original

      @user_to_update.app_progress.onboarding = nil

      GT::UserManager.update_app_progress_onboarding(@user_to_update)
      @user_to_update.app_progress.onboarding.should eql false
    end

    it "should do nothing if the value of onboarding is already false or true" do
      @user_to_update.should_not_receive(:save)

      @user_to_update.app_progress.onboarding = false

      GT::UserManager.update_app_progress_onboarding(@user_to_update)
      @user_to_update.app_progress.onboarding.should eql false

      @user_to_update.app_progress.onboarding = true

      GT::UserManager.update_app_progress_onboarding(@user_to_update)
      @user_to_update.app_progress.onboarding.should eql true
    end

    context "onboarding has an integer value" do
      it "should leave values < the number of onboarding steps as is" do
        @user_to_update.should_not_receive(:save)

        @user_to_update.app_progress.onboarding = Settings::Onboarding.num_steps - 1

        GT::UserManager.update_app_progress_onboarding(@user_to_update)
        @user_to_update.app_progress.onboarding.should == Settings::Onboarding.num_steps - 1
      end

      it "should set values >= the number of onboarding steps to true" do
        @user_to_update.should_receive(:save).twice.and_call_original

        @user_to_update.app_progress.onboarding = Settings::Onboarding.num_steps

        GT::UserManager.update_app_progress_onboarding(@user_to_update)
        @user_to_update.app_progress.onboarding.should == true

        @user_to_update.app_progress.onboarding = Settings::Onboarding.num_steps + 1

        GT::UserManager.update_app_progress_onboarding(@user_to_update)
        @user_to_update.app_progress.onboarding.should == true
      end
    end

    it "should make any other values true" do
      @user_to_update.should_receive(:save).once.and_call_original

      @user_to_update.app_progress.onboarding = 'true'

      GT::UserManager.update_app_progress_onboarding(@user_to_update)
      @user_to_update.app_progress.onboarding.should eql true
    end
  end

  context "create_user" do

    context "from omniauth" do
      before(:each) do
        @roll = Factory.create(:roll)
        Roll.stub(:find).and_return( @roll )
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
        u.nickname.should eql("dan-spinosa")

        @omniauth_hash['uid'] += "2"
        @omniauth_hash["info"]["nickname"] = " spinosa"
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash)
        u.valid?.should eql(true)
        u.nickname.should eql("-spinosa")

        @omniauth_hash['uid'] += "2"
        @omniauth_hash["info"]["nickname"] = "spinosa "
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash)
        u.valid?.should eql(true)
        u.nickname.should eql("spinosa-")

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
        u.nickname.start_with?("the-name").should == true
      end

      it 'should handle facebook user with no name or nickname' do
        omniauth_hash = {
          'credentials' => {
            'token' => "somelongtoken",
            'secret' => 'foreskin',
            'garbage' => 'truck'
          },
          'info' => {
            'email' => "blahblah@test.com",
            'garbage' => 99
          },
          'more_garbage' => Date.new
        }

        u = GT::UserManager.create_new_user_from_omniauth(omniauth_hash)

        u.valid?.should eql(true)
        u.nickname.start_with?("blahblah").should == true
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

      it "should follow the shelby roll" do
        ResqueSpec.reset!
        u = GT::UserManager.create_new_user_from_omniauth(@omniauth_hash)
        AddFollower.should have_queue_size_of(1)
        AddFollower.should have_queued(@roll.id, u.id, false)
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
        @shelby_roll = Factory.create(:roll, :id => Settings::Roll.shelby_roll_id)
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

      it "should return invalid user if nickname is taken by a *real* user" do
        lambda {
          #create real user with this nickname
          u1 = GT::UserManager.create_new_user_from_params(@params)
          u1.reload.user_type.should == User::USER_TYPE[:real]

          @params[:primary_email] = Factory.next(:primary_email)
          u2 = GT::UserManager.create_new_user_from_params(@params)
          u2.valid?.should == false
          u2.persisted?.should == false
        }.should change { User.count } .by(1)
      end

      it "should *steal* nickname and still create user if nickname is taken by a *faux* user" do
        lambda {
          # create FAUX user with the desired nickname
          u1 = Factory.create(:user, :nickname => @params[:nickname], :user_type => User::USER_TYPE[:faux])

          @params[:primary_email] = Factory.next(:primary_email)
          u2 = GT::UserManager.create_new_user_from_params(@params)
          u2.valid?.should == true
          u2.persisted?.should == true
          u2.nickname.should == @params[:nickname]
          u1.reload.nickname.should_not == @params[:nickname]
        }.should change { User.count } .by(2)
      end

      it "should fail and return error if email is taken" do
        lambda {
          u1 = GT::UserManager.create_new_user_from_params(@params)
          @params[:nickname] = Factory.next :nickname
          u2 = GT::UserManager.create_new_user_from_params(@params)
          u2.valid?.should == false
          u2.errors.should be_a ActiveModel::Errors
          u2.errors.messages.include?(:primary_email).should == true
        }.should change { User.count } .by(1)
      end

      it "should create and persist public, watch_later, upvoted, viwed Rolls for new User" do
        u = GT::UserManager.create_new_user_from_params(@params)

        u.public_roll.class.should == Roll
        u.public_roll.persisted?.should == true
        MongoMapper::Plugins::IdentityMap.clear
        u.public_roll.roll_type.should == Roll::TYPES[:special_public_real_user]

        u.watch_later_roll.class.should == Roll
        u.watch_later_roll.persisted?.should == true

        u.upvoted_roll.class.should == Roll
        u.upvoted_roll.upvoted_roll.should == true
        u.upvoted_roll.persisted?.should == true

        u.viewed_roll.class.should == Roll
        u.viewed_roll.persisted?.should == true
      end

      it "should create new user for anonymous, user_type == anonymous, user" do
        params = {:nickname => Factory.next(:nickname), :password => "password", :anonymous => true}
        lambda {
          u = GT::UserManager.create_new_user_from_params(params)
          u.valid?.should == true
          u.persisted?.should == true
          u.gt_enabled?.should == true
          u.cohorts.size.should > 0
          u.nickname.should == params[:nickname]
          u.user_type.should == User::USER_TYPE[:anonymous]
          MongoMapper::Plugins::IdentityMap.clear
          u.public_roll.roll_type.should == Roll::TYPES[:special_public]
        }.should change { User.count } .by(1)
      end

      it "should follow the shelby roll" do
        ResqueSpec.reset!
        r = Factory.create(:roll)
        Roll.stub(:find).and_return( r )
        u = GT::UserManager.create_new_user_from_params(@params)
        AddFollower.should have_queue_size_of(1)
        AddFollower.should have_queued(r.id, u.id, false)
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
            friend_ranker_double = double("friend_ranker", :get_friends_sorted_by_rank => [])
            GT::FacebookFriendRanker.stub(:new).and_return(friend_ranker_double)

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

      context "anonymous user" do

        before(:each) do
          @u = Factory.create(:user, :user_type => User::USER_TYPE[:anonymous], :app_progress => AppProgress.new)
          @public_roll = Factory.create(:roll, :creator => @u, :roll_type => Roll::TYPES[:special_public])
          @u.public_roll = @public_roll
        end

        it "converts an anonymous user and sets their nickname" do
          updated_u = GT::UserManager.add_new_auth_from_omniauth(@u, @new_omniauth_hash)
          updated_u.user_type.should == User::USER_TYPE[:converted]
          updated_u.nickname.should == @nickname
          MongoMapper::Plugins::IdentityMap.clear
          @public_roll.reload.roll_type.should == Roll::TYPES[:special_public_real_user]
        end

        it "changes the nickname pulled from omniauth if it's taken" do
          user_already_has_nickname = Factory.create(:user, :nickname => @nickname, :user_type => User::USER_TYPE[:anonymous])

          updated_u = GT::UserManager.add_new_auth_from_omniauth(@u, @new_omniauth_hash)
          @u.nickname.should_not == @nickname
          @u.nickname.should be_start_with @nickname
        end

        it "sets app_progress.onboarding to true when converting an anonymous user" do
          updated_u = GT::UserManager.add_new_auth_from_omniauth(@u, @new_omniauth_hash)
          updated_u.app_progress.onboarding.should == true
        end
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

  context "fix_inconsistent_user_images" do
    before(:each) do
      @user = Factory.create(:user)
      @user.authentications.to_ary.find{ |a| a.provider == 'twitter'}.image = Settings::Twitter.dummy_twitter_avatar_image_url
    end

    context "facebook user image" do
      before (:each) do
        @user.user_image = "http://graph.facebook.com/1234/picture"
      end

      it "copies user_image to user_image_original, if user_image_original is nil" do
        @user.user_image_original = nil

        expect(GT::UserManager.fix_inconsistent_user_images(@user)).to be_true

        expect(@user.user_image_original).to eql "http://graph.facebook.com/1234/picture"
      end

      it "resets user_image AND user_image_original based on the user's twitter auth, if user_image_original is a twitter image" do
        @user.user_image_original = 'http://a2.twimg.com/profile_images/1165820679/reece_-_bio_pic_normal.png'

        expect(GT::UserManager.fix_inconsistent_user_images(@user)).to be_true

        expect(@user.user_image).to eql Settings::Twitter.dummy_twitter_avatar_image_url
        expect(@user.user_image_original).to eql "http://dummy.twimg.com/profile_images/2284174872/7df3h38zabcvjylnyfe3.png"
      end

      it "does nothing otherwise" do
        expect {
          GT::UserManager.fix_inconsistent_user_images(@user)
        }.not_to change(@user, :user_image)

        expect {
          GT::UserManager.fix_inconsistent_user_images(@user)
        }.not_to change(@user, :user_image_original)
      end
    end

    context "twitter user image" do
      before(:each) do
        @user.user_image = 'http://a2.twimg.com/profile_images/1165820679/reece_-_bio_pic_normal.jpeg'
        @user.user_image_original = 'http://a2.twimg.com/profile_images/1165820679/reece_-_bio_pic.jpeg'
      end

      it "resets user_image AND user_image_original based on the user's twitter auth, if what's in the twitter auth is different" do
        expect(GT::UserManager.fix_inconsistent_user_images(@user)).to be_true

        expect(@user.user_image).to eql Settings::Twitter.dummy_twitter_avatar_image_url
        expect(@user.user_image_original).to eql "http://dummy.twimg.com/profile_images/2284174872/7df3h38zabcvjylnyfe3.png"
      end

      it "does nothing, if what's in the twitter auth matches the current user_image" do
        @user.authentications.to_ary.find{ |a| a.provider == 'twitter'}.image = 'http://a2.twimg.com/profile_images/1165820679/reece_-_bio_pic_normal.jpeg'
        @res = nil

        expect {
          @res = GT::UserManager.fix_inconsistent_user_images(@user)
        }.not_to change(@user, :user_image)
        expect(@res).to be_false

        expect {
          GT::UserManager.fix_inconsistent_user_images(@user)
        }.not_to change(@user, :user_image_original)
      end
    end

    it "does nothing, if user_image is not a facebook image" do
      expect {
        GT::UserManager.fix_inconsistent_user_images(@user)
      }.not_to change(@user, :user_image)

      expect {
        GT::UserManager.fix_inconsistent_user_images(@user)
      }.not_to change(@user, :user_image_original)
    end

    it "returns false if it doesn't update anything" do
      expect(GT::UserManager.fix_inconsistent_user_images(@user)).to be_false
    end

    it "doesn't blow up if the user_image is nil" do
      @user.user_image = nil
      @res = nil

      expect {
        @res = GT::UserManager.fix_inconsistent_user_images(@user)
      }.not_to raise_error
      expect(@res).to be_false
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
