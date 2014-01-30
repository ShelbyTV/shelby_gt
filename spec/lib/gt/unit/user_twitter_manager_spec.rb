# encoding: UTF-8

require 'spec_helper'

require 'user_twitter_manager'

# UNIT test
describe GT::UserTwitterManager do

  context "verify_auth" do
    it "should return true if TWT calls returns without throwing exception" do
      APIClients::TwitterClient.stub_chain(:build_for_token_and_secret, :statuses, :home_timeline?).and_return :whatever
      GT::UserTwitterManager.verify_auth(:what, :ever).should == true
    end

    it "should return false if TWT call throws exception" do
      APIClients::TwitterClient.stub_chain(:build_for_token_and_secret, :statuses, :home_timeline?).and_throw Grackle::TwitterError
      GT::UserTwitterManager.verify_auth(:what, :ever).should == false
    end

  end

  context "follow_all_friends_public_rolls" do
    before(:each) do
      @user = Factory.create(:user)

      @user_ids = [111998123958, 2111998123958] #twitter returns these as ints, we need to make them strings
      GT::UserTwitterManager.stub(:friends_ids).and_return(@user_ids)

      @friend1 = Factory.create(:user)
      @friend1.public_roll = Factory.create(:roll, :creator => @friend1)
      @friend1.save
      User.stub(:first).with( :conditions => { 'authentications.provider' => 'twitter', 'authentications.uid' => "111998123958" } ).and_return(@friend1)

      @friend2 = Factory.create(:user)
      @friend2.public_roll = Factory.create(:roll, :creator => @friend2)
      @friend2.save
      User.stub(:first).with( :conditions => { 'authentications.provider' => 'twitter', 'authentications.uid' => "2111998123958" } ).and_return(@friend2)
    end

    it "should follow public rolls of all friends" do
      @friend1.public_roll.should_receive(:add_follower).with(@user).exactly(1).times
      @friend2.public_roll.should_receive(:add_follower).with(@user).exactly(1).times
      GT::UserTwitterManager.follow_all_friends_public_rolls(@user)
    end

    it "should not follow roll if user has unfollowed it" do
      #follow and unfollow public roll of friend1
      @friend1.public_roll.add_follower(@user)
      @friend1.public_roll.remove_follower(@user)

      @friend1.public_roll.should_receive(:add_follower).with(@user).exactly(0).times
      @friend2.public_roll.should_receive(:add_follower).with(@user).exactly(1).times
      GT::UserTwitterManager.follow_all_friends_public_rolls(@user)
    end

    it "should gracefully handle friend ids not known to Shelby" do
      User.stub(:first).and_return(nil)

      #should not error
      GT::UserTwitterManager.follow_all_friends_public_rolls(@user)
    end

  end

  context "unfollow_twitter_faux_user" do
    before(:each) do
      @user = Factory.create(:user)

      @twitter_faux_user = Factory.create(:user, :user_type => User::USER_TYPE[:faux])
      @twitter_faux_user_public_roll = Factory.create(:roll, :creator => @twitter_faux_user)
      @twitter_faux_user.public_roll = @twitter_faux_user_public_roll
      @twitter_faux_user_public_roll.add_follower(@user)

      @twitter_real_user = Factory.create(:user)
      @twitter_real_user_public_roll = Factory.create(:roll, :creator => @twitter_real_user)
      @twitter_real_user.public_roll = @twitter_real_user_public_roll
      @twitter_real_user_public_roll.add_follower(@user)

    end

    it "unfollows the public roll of the twitter user if that user is a faux user" do
      expect(@user.roll_followings).to be_any {|rf| rf.roll_id == @twitter_faux_user.public_roll_id}

      expect {
        @res = GT::UserTwitterManager.unfollow_twitter_faux_user(@user, @twitter_faux_user.authentications.first.uid)
      }.to change(@user.roll_followings,:count).by(-1)

      expect(@user.roll_followings).not_to be_any {|rf| rf.roll_id == @twitter_faux_user.public_roll_id}
      expect(@user.rolls_unfollowed).not_to be_any {|roll_id| roll_id == @twitter_faux_user.public_roll_id}
      expect(@res).to be_true
    end

    it "does nothing if the twitter user is a real user" do
      expect {
        @res = GT::UserTwitterManager.unfollow_twitter_faux_user(@user, @twitter_real_user.authentications.first.uid)
      }.not_to change(@user.roll_followings,:count)

      expect(@res).to be_false
    end

    it "does not get confused by matching uid from another provider" do
      @twitter_faux_user.authentications.first.provider = 'facebook'
      @twitter_faux_user.save

      expect {
        @res = GT::UserTwitterManager.unfollow_twitter_faux_user(@user, @twitter_faux_user.authentications.first.uid)
      }.not_to change(@user.roll_followings,:count)

      expect(@res).to be_false
    end

    it "does nothing if the twitter uid doesn't exist" do
      expect {
        @res = GT::UserTwitterManager.unfollow_twitter_faux_user(@user, 'baduid')
      }.not_to change(@user.roll_followings,:count)

      expect(@res).to be_false
    end

    it "does nothing if the user isn't following the twitter user in question on Shelby" do
      twitter_faux_user2 = Factory.create(:user, :user_type => User::USER_TYPE[:faux])
      twitter_faux_user2_public_roll = Factory.create(:roll, :creator => twitter_faux_user2)
      twitter_faux_user2.public_roll = twitter_faux_user2_public_roll

      expect {
        @res = GT::UserTwitterManager.unfollow_twitter_faux_user(@user, twitter_faux_user2.authentications.first.uid)
      }.not_to change(@user.roll_followings,:count).by(-1)

      expect(@res).to be_false
    end
  end

  context "update_user_twitter_avatar" do
    before(:each) do
      @user = Factory.create(:user, :user_image => 'http://shelby.tv/nontwitteravatar.png')
    end

    it "updates the user's twitter auth" do
      GT::UserTwitterManager.update_user_twitter_avatar(@user, Settings::Twitter.dummy_twitter_avatar_image_url)
      @user.reload

      expect(@user.authentications.first.image).to eql Settings::Twitter.dummy_twitter_avatar_image_url
    end

    it "knows which auth to update if there's a Facebook auth too" do
      twitter_auth = @user.authentications.first
      new_auth = Authentication.new(:provider => 'facebook', :uid => twitter_auth.uid, :image => 'someotherimage.png')
      @user.authentications.unshift(new_auth)
      @user.save

      GT::UserTwitterManager.update_user_twitter_avatar(@user, Settings::Twitter.dummy_twitter_avatar_image_url)
      @user.reload

      expect(@user.authentications.to_ary.find{ |a| a.provider == 'twitter' }.image).to eql Settings::Twitter.dummy_twitter_avatar_image_url
      expect(@user.authentications.to_ary.find{ |a| a.provider == 'facebook' }.image).to eql "someotherimage.png"
    end

    it "does nothing to the user's user_image or user_image_original if their old user_image is not a twitter avatar" do
      expect {
        GT::UserTwitterManager.update_user_twitter_avatar(@user, Settings::Twitter.dummy_twitter_avatar_image_url)
        @user.reload
      }.not_to change(@user, :user_image)

      expect {
        GT::UserTwitterManager.update_user_twitter_avatar(@user, Settings::Twitter.dummy_twitter_avatar_image_url)
        @user.reload
      }.not_to change(@user, :user_image_original)
    end

    it "updates the user's user_image if their old user_image is an old style, non-secure twitter avatar" do
      @user.user_image = 'http://a2.twimg.com/profile_images/1165820679/reece_-_bio_pic_normal.jpg'
      @user.save

      GT::UserTwitterManager.update_user_twitter_avatar(@user, Settings::Twitter.dummy_twitter_avatar_image_url)
      @user.reload

      expect(@user.user_image).to eql Settings::Twitter.dummy_twitter_avatar_image_url
    end

    it "updates the user's user_image if their old user_image is a new style, secure twitter avatar" do
      @user.user_image = 'https://pbs.twimg.com/profile_images/2284174872/7df3h38zabcvjylnyfe3_normal.png'
      @user.save

      GT::UserTwitterManager.update_user_twitter_avatar(@user, Settings::Twitter.dummy_twitter_avatar_image_url)
      @user.reload

      expect(@user.user_image).to eql Settings::Twitter.dummy_twitter_avatar_image_url
    end

    it "updates the user's user_image if their old user_image is a default twitter avatar" do
      @user.user_image = 'http://a0.twimg.com/sticky/default_profile_images/default_profile_6_normal.png'
      @user.save

      GT::UserTwitterManager.update_user_twitter_avatar(@user, Settings::Twitter.dummy_twitter_avatar_image_url)
      @user.reload

      expect(@user.user_image).to eql Settings::Twitter.dummy_twitter_avatar_image_url
    end

    it "updates the user's user_image_original when it updates the user_image" do
      @user.user_image = 'http://a2.twimg.com/profile_images/1165820679/reece_-_bio_pic_normal.jpg'
      @user.save

      GT::UserTwitterManager.update_user_twitter_avatar(@user, Settings::Twitter.dummy_twitter_avatar_image_url)
      @user.reload

      expect(@user.user_image_original).to eql 'http://dummy.twimg.com/profile_images/2284174872/7df3h38zabcvjylnyfe3.png'
    end
  end

  context "udpate_all_twitter_avatars" do
    before(:each) do
      MongoMapper::Helper.drop_all_dbs
      MongoMapper::Helper.ensure_all_indexes

      @user_with_twitter_oauth = Factory.create(:user)

      @users_route = double("users_route")
      @twitter_client_for_app = double("twitter_client_for_app", :users => @users_route)
      APIClients::TwitterClient.stub(:build_for_app).and_return(@twitter_client_for_app)

      Grackle::TwitterError.any_instance.stub(:response_object).and_return(OpenStruct.new(:errors => nil))
    end


    context "users with twitter oauth credentials" do

      it "immediately updates twitter avatar" do
        MongoMapper::Plugins::IdentityMap.clear

        APIClients::TwitterInfoGetter.should_receive(:new).exactly(1).times().with(@user_with_twitter_oauth)
        APIClients::TwitterClient.should_not_receive(:build_for_app)

        expect(GT::UserTwitterManager.update_all_twitter_avatars).to eql({
          :users_with_twitter_auth_found => 1,
          :users_with_valid_oauth_creds_found => 1,
          :users_without_valid_oauth_creds_found => 0,
          :users_with_valid_oauth_creds_updated => 1,
          :users_without_valid_oauth_creds_updated => 0
        })

        @user_with_twitter_oauth.reload
        expect(@user_with_twitter_oauth.authentications.first.image).to eql Settings::Twitter.dummy_twitter_avatar_image_url
      end

      it "notices when it gets rate limited and quits immediately" do
        MongoMapper::Plugins::IdentityMap.clear

        twitter_error = Grackle::TwitterError.new(:get, nil, 429, nil)
        @twt_info_getter.stub(:get_user_info).and_raise(twitter_error)

        Rails.logger.stub(:info).with(any_args())
        Rails.logger.should_receive(:info).once().with("WE GOT RATE LIMITED PER USER")

        expect(GT::UserTwitterManager.update_all_twitter_avatars).to eql({
          :users_with_twitter_auth_found => 1,
          :users_with_valid_oauth_creds_found => 1,
          :users_without_valid_oauth_creds_found => 0,
          :users_with_valid_oauth_creds_updated => 0,
          :users_without_valid_oauth_creds_updated => 0
        })
      end

      it "doesn't quit when it gets other kinds of twitter errors" do
        @another_user_with_twitter_oauth = Factory.create(:user)
        MongoMapper::Plugins::IdentityMap.clear

        twitter_error = Grackle::TwitterError.new(:get, nil, 404, nil)
        @twt_info_getter.should_receive(:get_user_info).ordered().and_raise(twitter_error)
        @twt_info_getter.should_receive(:get_user_info).ordered()

        Rails.logger.should_receive(:info).with("TWITTER EXCEPTION: #{twitter_error}")
        Rails.logger.should_not_receive(:info).with("WE GOT RATE LIMITED PER USER")

        expect(GT::UserTwitterManager.update_all_twitter_avatars).to eql({
          :users_with_twitter_auth_found => 2,
          :users_with_valid_oauth_creds_found => 2,
          :users_without_valid_oauth_creds_found => 0,
          :users_with_valid_oauth_creds_updated => 1,
          :users_without_valid_oauth_creds_updated => 0
        })
      end

      it "logs errors other than twitter errors and skips to the next user" do
        @another_user_with_twitter_oauth = Factory.create(:user)
        MongoMapper::Plugins::IdentityMap.clear

        exception = 'hello'

        GT::UserTwitterManager.stub(:update_user_twitter_avatar).with(@user_with_twitter_oauth, anything()).and_raise(exception)
        GT::UserTwitterManager.stub(:update_user_twitter_avatar).with(@another_user_with_twitter_oauth, anything()).and_call_original

        Rails.logger.stub(:info).with(any_args())
        Rails.logger.should_receive(:info).once().with("GENERAL EXCEPTION: #{exception}")

        expect(GT::UserTwitterManager.update_all_twitter_avatars).to eql({
          :users_with_twitter_auth_found => 2,
          :users_with_valid_oauth_creds_found => 2,
          :users_without_valid_oauth_creds_found => 0,
          :users_with_valid_oauth_creds_updated => 1,
          :users_without_valid_oauth_creds_updated => 0
        })
      end

    end

    context "users without twitter oauth credentials" do
      before(:each) do
        Settings::Twitter['user_lookup_slice_size'] = 2

        @users_without_twitter_oauth = []
        3.times do |i|
          @users_without_twitter_oauth[i] = Factory.create(:user)
          @users_without_twitter_oauth[i].authentications.first.oauth_token = nil
        end

        @users_without_twitter_oauth[1].user_image = 'https://pbs.twimg.com/profile_images/2284174872/7df3h38zabcvjylnyfe3_normal.png'

        3.times do |i|
          @users_without_twitter_oauth[i].save
        end

        MongoMapper::Plugins::IdentityMap.clear
      end

      it "batches twitter requests for slices of users" do
        APIClients::TwitterClient.should_receive(:build_for_app)

        @users_route.should_receive(:lookup!).ordered().with({
          :user_id => "#{@users_without_twitter_oauth[0].authentications.first.uid},#{@users_without_twitter_oauth[1].authentications.first.uid}",
          :include_entities => false
        }).and_return([
          OpenStruct.new(:id_str => @users_without_twitter_oauth[1].authentications.first.uid, :profile_image_url => Settings::Twitter.dummy_twitter_avatar_image_url),
          OpenStruct.new(:id_str => @users_without_twitter_oauth[0].authentications.first.uid, :profile_image_url => "http://somemaedupimage.png")
        ])
        @users_route.should_receive(:lookup!).ordered().with({
          :user_id => "#{@users_without_twitter_oauth[2].authentications.first.uid}",
          :include_entities => false
        }).and_return([
          OpenStruct.new(:id_str => @users_without_twitter_oauth[2].authentications.first.uid, :profile_image_url => "http://someothermadeupimage.png")
        ])

        expect(GT::UserTwitterManager.update_all_twitter_avatars).to eql({
          :users_with_twitter_auth_found => 4,
          :users_with_valid_oauth_creds_found => 1,
          :users_without_valid_oauth_creds_found => 3,
          :users_with_valid_oauth_creds_updated => 1,
          :users_without_valid_oauth_creds_updated => 3
        })

        expect {
          @users_without_twitter_oauth[0].reload
        }.not_to change(@users_without_twitter_oauth[0], :user_image)
        expect(@users_without_twitter_oauth[0].authentications.first.image).to eql "http://somemaedupimage.png"

        @users_without_twitter_oauth[1].reload
        expect(@users_without_twitter_oauth[1].authentications.first.image).to eql Settings::Twitter.dummy_twitter_avatar_image_url
        expect(@users_without_twitter_oauth[1].user_image).to eql Settings::Twitter.dummy_twitter_avatar_image_url
        expect(@users_without_twitter_oauth[1].user_image_original).to eql "http://dummy.twimg.com/profile_images/2284174872/7df3h38zabcvjylnyfe3.png"

        expect {
          @users_without_twitter_oauth[2].reload
        }.not_to change(@users_without_twitter_oauth[2], :user_image)
        expect(@users_without_twitter_oauth[2].authentications.first.image).to eql "http://someothermadeupimage.png"
      end

      it "notices when it gets rate limited and quits immediately" do
        twitter_error = Grackle::TwitterError.new(:get, nil, 429, nil)
        @users_route.stub(:lookup!).and_raise(twitter_error)

        Rails.logger.stub(:info).with(any_args())
        Rails.logger.should_receive(:info).once().with("WE GOT RATE LIMITED PER APP")

        expect(GT::UserTwitterManager.update_all_twitter_avatars).to eql({
          :users_with_twitter_auth_found => 4,
          :users_with_valid_oauth_creds_found => 1,
          :users_without_valid_oauth_creds_found => 3,
          :users_with_valid_oauth_creds_updated => 1,
          :users_without_valid_oauth_creds_updated => 0
        })
      end

      it "doesn't quit when it gets other kinds of twitter errors" do
        twitter_error = Grackle::TwitterError.new(:get, nil, 404, nil)
        @users_route.stub(:lookup!).ordered().and_raise(twitter_error)
        @users_route.stub(:lookup!).ordered().with({
          :user_id => "#{@users_without_twitter_oauth[2].authentications.first.uid}",
          :include_entities => false
        }).and_return([
          OpenStruct.new(:id_str => @users_without_twitter_oauth[2].authentications.first.uid, :profile_image_url => "http://someothermadeupimage.png")
        ])

        Rails.logger.stub(:info).with(any_args())
        Rails.logger.should_receive(:info).once().with("TWITTER EXCEPTION: #{twitter_error}")
        Rails.logger.should_not_receive(:info).with("WE GOT RATE LIMITED PER APP")

        expect(GT::UserTwitterManager.update_all_twitter_avatars).to eql({
          :users_with_twitter_auth_found => 4,
          :users_with_valid_oauth_creds_found => 1,
          :users_without_valid_oauth_creds_found => 3,
          :users_with_valid_oauth_creds_updated => 1,
          :users_without_valid_oauth_creds_updated => 1
        })
      end

      it "logs errors other than twitter errors and skips to the next user" do
        @users_route.stub(:lookup!).with({
          :user_id => "#{@users_without_twitter_oauth[0].authentications.first.uid},#{@users_without_twitter_oauth[1].authentications.first.uid}",
          :include_entities => false
        }).and_return([
          OpenStruct.new(:id_str => @users_without_twitter_oauth[1].authentications.first.uid, :profile_image_url => Settings::Twitter.dummy_twitter_avatar_image_url),
          OpenStruct.new(:id_str => @users_without_twitter_oauth[0].authentications.first.uid, :profile_image_url => "http://somemaedupimage.png")
        ])
        @users_route.stub(:lookup!).with({
          :user_id => "#{@users_without_twitter_oauth[2].authentications.first.uid}",
          :include_entities => false
        }).and_return([
          OpenStruct.new(:id_str => @users_without_twitter_oauth[2].authentications.first.uid, :profile_image_url => "http://someothermadeupimage.png")
        ])

        exception = 'hello'

        GT::UserTwitterManager.stub(:update_user_twitter_avatar).and_call_original
        GT::UserTwitterManager.stub(:update_user_twitter_avatar).with(@users_without_twitter_oauth[1], anything()).and_raise(exception)

        Rails.logger.stub(:info).with(any_args())
        Rails.logger.should_receive(:info).once().with("GENERAL EXCEPTION: #{exception}")

        expect(GT::UserTwitterManager.update_all_twitter_avatars).to eql({
          :users_with_twitter_auth_found => 4,
          :users_with_valid_oauth_creds_found => 1,
          :users_without_valid_oauth_creds_found => 3,
          :users_with_valid_oauth_creds_updated => 1,
          :users_without_valid_oauth_creds_updated => 2
        })
      end
    end

    context "users with invalid twitter oauth credentials" do
      before(:each) do
        Settings::Twitter['user_lookup_slice_size'] = 2
        @user_with_invalid_twitter_oauth = Factory.create(:user)
        @another_user_with_twitter_oauth = Factory.create(:user)
        @user_without_twitter_oauth = Factory.create(:user)
        @user_without_twitter_oauth.authentications.first.oauth_token = nil
        @user_without_twitter_oauth.save
        MongoMapper::Plugins::IdentityMap.clear

        twitter_error = Grackle::TwitterError.new(:get, nil, 401, "{\"errors\":[{\"message\":\"Invalid or expired token\",\"code\":89}]}")
        twitter_error_struct = OpenStruct.new(:message => "Invalid or expired token", :code => 89)
        twitter_response_object = OpenStruct.new(:errors => [twitter_error_struct])
        twitter_error.should_receive(:response_object).at_least(:once).and_return(twitter_response_object)

        @twt_info_getter.should_receive(:get_user_info).ordered()
        @twt_info_getter.should_receive(:get_user_info).ordered().and_raise(twitter_error)
        @twt_info_getter.should_receive(:get_user_info).ordered()

        Rails.logger.stub(:info).with(any_args())
        Rails.logger.should_receive(:info).once().with("User oauth creds invalid, will process later with application auth")
      end

      it "processes the user along with the users for whom we have no oauth credentials" do
        @users_route.should_receive(:lookup!).with({
          :user_id => "#{@user_with_invalid_twitter_oauth.authentications.first.uid},#{@user_without_twitter_oauth.authentications.first.uid}",
          :include_entities => false
        }).and_return([
          OpenStruct.new(:id_str => @user_without_twitter_oauth.authentications.first.uid, :profile_image_url => Settings::Twitter.dummy_twitter_avatar_image_url),
          OpenStruct.new(:id_str => @user_with_invalid_twitter_oauth.authentications.first.uid, :profile_image_url => Settings::Twitter.dummy_twitter_avatar_image_url)
        ])

        expect(GT::UserTwitterManager.update_all_twitter_avatars).to eql({
          :users_with_twitter_auth_found => 4,
          :users_with_valid_oauth_creds_found => 2,
          :users_without_valid_oauth_creds_found => 2,
          :users_with_valid_oauth_creds_updated => 2,
          :users_without_valid_oauth_creds_updated => 2
        })

        @user_with_invalid_twitter_oauth.reload
        expect(@user_with_invalid_twitter_oauth.authentications.first.image).to eql Settings::Twitter.dummy_twitter_avatar_image_url
      end

      it "has a mode to process only users for whom we have invalid oauth credentials" do
        @users_route.should_receive(:lookup!).with({
          :user_id => "#{@user_with_invalid_twitter_oauth.authentications.first.uid}",
          :include_entities => false
        }).and_return([
          OpenStruct.new(:id_str => @user_with_invalid_twitter_oauth.authentications.first.uid, :profile_image_url => Settings::Twitter.dummy_twitter_avatar_image_url),
        ])

        expect(GT::UserTwitterManager.update_all_twitter_avatars({:invalid_credentials_only => true})).to eql({
          :users_with_twitter_auth_found => 4,
          :users_with_valid_oauth_creds_found => 2,
          :users_without_valid_oauth_creds_found => 2,
          :users_with_valid_oauth_creds_updated => 0,
          :users_without_valid_oauth_creds_updated => 1
        })

        @user_with_invalid_twitter_oauth.reload
        expect(@user_with_invalid_twitter_oauth.authentications.first.image).to eql Settings::Twitter.dummy_twitter_avatar_image_url

        expect {
          @user_with_twitter_oauth.reload
        }.not_to change(@user_with_twitter_oauth.authentications.first, :image)

        expect {
          @another_user_with_twitter_oauth.reload
        }.not_to change(@another_user_with_twitter_oauth.authentications.first, :image)

        expect {
          @user_without_twitter_oauth.reload
        }.not_to change(@user_with_invalid_twitter_oauth.authentications.first, :image)
      end
    end
  end
end