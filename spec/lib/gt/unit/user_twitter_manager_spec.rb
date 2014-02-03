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

  context "url_is_twitter_avatar?" do
    it "returns true for a new style twitter avatar" do
      expect(GT::UserTwitterManager.url_is_twitter_avatar?(
        'https://pbs.twimg.com/profile_images/2284174872/7df3h38zabcvjylnyfe3_normal.png'
      )).to be_true

      expect(GT::UserTwitterManager.url_is_twitter_avatar?(
        'http://pbs.twimg.com/profile_images/2284174872/7df3h38zabcvjylnyfe3_normal.png'
      )).to be_true

      expect(GT::UserTwitterManager.url_is_twitter_avatar?(
        'http://pbs.twimg.com/profile_images/2284174872/7df3h38zabcvjylnyfe3_normal.jpg'
      )).to be_true
    end

    it "returns true for an old style twitter avatar" do
      expect(GT::UserTwitterManager.url_is_twitter_avatar?(
        'http://a2.twimg.com/profile_images/1165820679/reece_-_bio_pic_normal.png'
      )).to be_true

      expect(GT::UserTwitterManager.url_is_twitter_avatar?(
        'https://a2.twimg.com/profile_images/1165820679/reece_-_bio_pic_normal.png'
      )).to be_true

      expect(GT::UserTwitterManager.url_is_twitter_avatar?(
        'http://a2.twimg.com/profile_images/1165820679/reece_-_bio_pic_normal.jpg'
      )).to be_true
    end

    it "returns true for a twitter default avatar" do
      expect(GT::UserTwitterManager.url_is_twitter_avatar?(
        'http://a0.twimg.com/sticky/default_profile_images/default_profile_6_normal.png'
      )).to be_true

      expect(GT::UserTwitterManager.url_is_twitter_avatar?(
        'https://a0.twimg.com/sticky/default_profile_images/default_profile_6_normal.png'
      )).to be_true
    end

    it "returns false for any other url" do
      expect(GT::UserTwitterManager.url_is_twitter_avatar?(
        'http://pbs.twimg.com/profile_images/2284174872/7df3h38zabcvjylnyfe3_normal.tiff'
      )).to be_false

      expect(GT::UserTwitterManager.url_is_twitter_avatar?(
        'http://shelby.tv/avatar.png'
      )).to be_false

      expect(GT::UserTwitterManager.url_is_twitter_avatar?(
        'http://www.espn.com'
      )).to be_false
    end
  end

  context "udpate_all_twitter_avatars" do
    before(:each) do
      Settings::Twitter['user_lookup_batch_size'] = 2
      Settings::Twitter['user_lookup_max_requests_per_oauth'] = 100

      MongoMapper::Helper.drop_all_dbs
      MongoMapper::Helper.ensure_all_indexes

      @users_route = double("users_route")
      @users_route.stub(:lookup!).and_return([])
      @twitter_client = double("twitter_client", :users => @users_route)
      APIClients::TwitterClient.stub(:build_for_token_and_secret).and_return(@twitter_client)
      APIClients::TwitterClient.stub(:build_for_app).and_return(@twitter_client)

      Grackle::TwitterError.any_instance.stub(:response_object).and_return(OpenStruct.new(:errors => nil))
    end

    context "mixed user and non-user creds" do
      before(:each) do
        @users = []
        2.times do |i|
          user_with_twitter_oauth = Factory.create(:user)
          user_with_twitter_oauth.authentications.first.oauth_token = "token#{i}"
          user_with_twitter_oauth.authentications.first.oauth_secret = "secret#{i}"
          user_with_twitter_oauth.save
          @users << user_with_twitter_oauth
          user_without_twitter_oauth = Factory.create(:user)
          user_without_twitter_oauth.authentications.first.oauth_token = nil
          user_without_twitter_oauth.save
          @users << user_without_twitter_oauth
        end
      end

      it "builds twitter clients with oauth creds from examined users and keeps them for a specified number of requests" do
        MongoMapper::Plugins::IdentityMap.clear

        Settings::Twitter['user_lookup_max_requests_per_oauth'] = 1

        APIClients::TwitterClient.should_receive(:build_for_token_and_secret).once().ordered().with(
          "token1",
          "secret1"
        )

        APIClients::TwitterClient.should_receive(:build_for_token_and_secret).once().ordered().with(
          "token0",
          "secret0"
        )

        GT::UserTwitterManager.update_all_twitter_avatars
      end

      it "works when it has user creds from the very first user" do
        user_with_twitter_oauth = Factory.create(:user)
        user_with_twitter_oauth.authentications.first.oauth_token = "tokenN"
        user_with_twitter_oauth.authentications.first.oauth_secret = "secretN"
        user_with_twitter_oauth.save
        MongoMapper::Plugins::IdentityMap.clear

        Settings::Twitter['user_lookup_max_requests_per_oauth'] = 1
        Settings::Twitter['user_lookup_batch_size'] = 1

        APIClients::TwitterClient.should_receive(:build_for_token_and_secret).once().ordered().with(
          "tokenN",
          "secretN"
        )

        APIClients::TwitterClient.should_receive(:build_for_app).once().ordered

        APIClients::TwitterClient.should_receive(:build_for_token_and_secret).once().ordered().with(
          "token1",
          "secret1"
        )

        APIClients::TwitterClient.should_receive(:build_for_app).once().ordered

        APIClients::TwitterClient.should_receive(:build_for_token_and_secret).once().ordered().with(
          "token0",
          "secret0"
        )

        GT::UserTwitterManager.update_all_twitter_avatars
      end

      it "batches twitter requests for slices of users and updates their twitter avatars with the returned data" do
        @users[0].user_image = 'https://pbs.twimg.com/profile_images/2284174872/7df3h38zabcvjylnyfe3_normal.png'
        @users[0].save
        MongoMapper::Plugins::IdentityMap.clear

        @users_route.should_receive(:lookup!).with({
          :user_id => "#{@users[3].authentications.first.uid},#{@users[2].authentications.first.uid}",
          :include_entities => false
        }).and_return([
          OpenStruct.new(:id_str => @users[2].authentications.first.uid, :profile_image_url => "http://2.png"),
          OpenStruct.new(:id_str => @users[3].authentications.first.uid, :profile_image_url => "http://3.png")
        ])
        @users_route.should_receive(:lookup!).with({
          :user_id => "#{@users[1].authentications.first.uid},#{@users[0].authentications.first.uid}",
          :include_entities => false
        }).and_return([
          OpenStruct.new(:id_str => @users[1].authentications.first.uid, :profile_image_url => "http://1.png"),
          OpenStruct.new(:id_str => @users[0].authentications.first.uid, :profile_image_url => Settings::Twitter.dummy_twitter_avatar_image_url)
        ])

        expect(GT::UserTwitterManager.update_all_twitter_avatars).to eql({
          :users_with_twitter_auth_found => 4,
          :users_with_twitter_auth_updated => 4
        })

        @users[0].reload
        expect(@users[0].authentications.first.image).to eql Settings::Twitter.dummy_twitter_avatar_image_url
        expect(@users[0].user_image).to eql Settings::Twitter.dummy_twitter_avatar_image_url
        expect(@users[0].user_image_original).to eql "http://dummy.twimg.com/profile_images/2284174872/7df3h38zabcvjylnyfe3.png"

        (1..3).each do |i|
          expect {
            @users[i].reload
          }.not_to change(@users[i], :user_image)
          expect(@users[i].authentications.first.image).to eql "http://#{i}.png"
        end
      end

      it "processes one last batch with any users that are left over at the end" do
        one_more_user = Factory.create(:user)
        one_more_user.authentications.first.oauth_token = "token5"
        one_more_user.authentications.first.oauth_secret = "secret5"
        one_more_user.save
        @users << one_more_user
        MongoMapper::Plugins::IdentityMap.clear

        @users_route.should_receive(:lookup!).with({
          :user_id => "#{@users[4].authentications.first.uid},#{@users[3].authentications.first.uid}",
          :include_entities => false
        }).and_return([
          OpenStruct.new(:id_str => @users[3].authentications.first.uid, :profile_image_url => "http://3.png"),
          OpenStruct.new(:id_str => @users[4].authentications.first.uid, :profile_image_url => "http://4.png")
        ])
        @users_route.should_receive(:lookup!).with({
          :user_id => "#{@users[2].authentications.first.uid},#{@users[1].authentications.first.uid}",
          :include_entities => false
        }).and_return([
          OpenStruct.new(:id_str => @users[2].authentications.first.uid, :profile_image_url => "http://2.png"),
          OpenStruct.new(:id_str => @users[1].authentications.first.uid, :profile_image_url => "http://1.png")
        ])
        @users_route.should_receive(:lookup!).with({
          :user_id => "#{@users[0].authentications.first.uid}",
          :include_entities => false
        }).and_return([
          OpenStruct.new(:id_str => @users[0].authentications.first.uid, :profile_image_url => "http://0.png"),
        ])

        expect(GT::UserTwitterManager.update_all_twitter_avatars).to eql({
          :users_with_twitter_auth_found => 5,
          :users_with_twitter_auth_updated => 5
        })

        (0..4).each do |i|
          expect {
            @users[i].reload
          }.not_to change(@users[i], :user_image)
          expect(@users[i].authentications.first.image).to eql "http://#{i}.png"
        end
      end

      it "limits the number of users processed based on the :limit option" do

        @users_route.should_receive(:lookup!).exactly(:once).with({
          :user_id => "#{@users[3].authentications.first.uid}",
          :include_entities => false
        }).and_return([
          OpenStruct.new(:id_str => @users[3].authentications.first.uid, :profile_image_url => "http://0.png"),
        ])

        expect(GT::UserTwitterManager.update_all_twitter_avatars(:limit => 1)).to eql({
          :users_with_twitter_auth_found => 1,
          :users_with_twitter_auth_updated => 1
        })

      end

      it "moves on to another set of user oauth creds if twitter response indicates that current creds are invalid" do
        MongoMapper::Plugins::IdentityMap.clear

        users_route_client1 = double("users_route_client1")
        users_route_client2 = double("users_route_client2")
        twitter_client1 = double("twitter_client1", :users => users_route_client1)
        twitter_client2 = double("twitter_client2", :users => users_route_client2)

        APIClients::TwitterClient.should_receive(:build_for_token_and_secret).exactly(:once).ordered().with(
          "token1",
          "secret1"
        ).and_return(twitter_client1)

        twitter_error = Grackle::TwitterError.new(:get, nil, 401, "{\"errors\":[{\"message\":\"Invalid or expired token\",\"code\":89}]}")
        twitter_error_struct = OpenStruct.new(:message => "Invalid or expired token", :code => 89)
        twitter_response_object = OpenStruct.new(:errors => [twitter_error_struct])
        twitter_error.should_receive(:response_object).at_least(:once).and_return(twitter_response_object)

        users_route_client1.should_receive(:lookup!).with({
          :user_id => "#{@users[3].authentications.first.uid},#{@users[2].authentications.first.uid}",
          :include_entities => false
        }).ordered().and_return([
          OpenStruct.new(:id_str => @users[2].authentications.first.uid, :profile_image_url => "http://2.png"),
          OpenStruct.new(:id_str => @users[3].authentications.first.uid, :profile_image_url => "http://3.png")
        ])
        users_route_client1.should_receive(:lookup!).with({
          :user_id => "#{@users[1].authentications.first.uid},#{@users[0].authentications.first.uid}",
          :include_entities => false
        }).ordered().and_raise(twitter_error)

        APIClients::TwitterClient.should_receive(:build_for_token_and_secret).exactly(:once).ordered().with(
          "token0",
          "secret0"
        ).and_return(twitter_client2)

        users_route_client2.should_receive(:lookup!).with({
          :user_id => "#{@users[1].authentications.first.uid},#{@users[0].authentications.first.uid}",
          :include_entities => false
        }).ordered().and_return([
          OpenStruct.new(:id_str => @users[1].authentications.first.uid, :profile_image_url => "http://1.png"),
          OpenStruct.new(:id_str => @users[0].authentications.first.uid, :profile_image_url => Settings::Twitter.dummy_twitter_avatar_image_url)
        ])

        Rails.logger.stub(:info).with(any_args())
        Rails.logger.should_receive(:info).once().with("User twitter creds invalid, will try new creds: #{twitter_error}")

        expect(GT::UserTwitterManager.update_all_twitter_avatars).to eql({
          :users_with_twitter_auth_found => 4,
          :users_with_twitter_auth_updated => 4
        })
      end

      it "notices when it gets rate limited and quits immediately" do
        MongoMapper::Plugins::IdentityMap.clear

        twitter_error = Grackle::TwitterError.new(:get, nil, 429, nil)
        @users_route.stub(:lookup!).with({
          :user_id => "#{@users[3].authentications.first.uid},#{@users[2].authentications.first.uid}",
          :include_entities => false
        }).and_return([
          OpenStruct.new(:id_str => @users[2].authentications.first.uid, :profile_image_url => Settings::Twitter.dummy_twitter_avatar_image_url),
          OpenStruct.new(:id_str => @users[3].authentications.first.uid, :profile_image_url => "http://somemaedupimage.png")
        ])
        @users_route.stub(:lookup!).with({
          :user_id => "#{@users[1].authentications.first.uid},#{@users[0].authentications.first.uid}",
          :include_entities => false
        }).and_raise(twitter_error)

        Rails.logger.stub(:info).with(any_args())
        Rails.logger.should_receive(:info).once().with("WE GOT RATE LIMITED PER USER")

        expect(GT::UserTwitterManager.update_all_twitter_avatars).to eql({
          :users_with_twitter_auth_found => 4,
          :users_with_twitter_auth_updated => 2
        })
      end

    it "doesn't quit when it gets other kinds of twitter errors" do
        MongoMapper::Plugins::IdentityMap.clear

        twitter_error = Grackle::TwitterError.new(:get, nil, 404, nil)
        @users_route.stub(:lookup!).with({
          :user_id => "#{@users[3].authentications.first.uid},#{@users[2].authentications.first.uid}",
          :include_entities => false
        }).and_raise(twitter_error)
        @users_route.stub(:lookup!).with({
          :user_id => "#{@users[1].authentications.first.uid},#{@users[0].authentications.first.uid}",
          :include_entities => false
        }).and_return([
          OpenStruct.new(:id_str => @users[1].authentications.first.uid, :profile_image_url => "http://1.png"),
          OpenStruct.new(:id_str => @users[0].authentications.first.uid, :profile_image_url => "http://2.png")
        ])

        Rails.logger.should_receive(:info).with("TWITTER EXCEPTION, SKIPPING BATCH: #{twitter_error}").once()
        Rails.logger.should_not_receive(:info).with("WE GOT RATE LIMITED PER USER")

        expect(GT::UserTwitterManager.update_all_twitter_avatars).to eql({
          :users_with_twitter_auth_found => 4,
          :users_with_twitter_auth_updated => 2
        })
      end

      it "logs errors other than twitter errors and skips to the next returned twitter user" do
        MongoMapper::Plugins::IdentityMap.clear

        exception = 'hello'

        @users_route.stub(:lookup!).with({
          :user_id => "#{@users[3].authentications.first.uid},#{@users[2].authentications.first.uid}",
          :include_entities => false
        }).and_return([
          OpenStruct.new(:id_str => @users[2].authentications.first.uid, :profile_image_url => Settings::Twitter.dummy_twitter_avatar_image_url),
          OpenStruct.new(:id_str => @users[3].authentications.first.uid, :profile_image_url => "http://somemaedupimage.png")
        ])
        @users_route.stub(:lookup!).with({
          :user_id => "#{@users[1].authentications.first.uid},#{@users[0].authentications.first.uid}",
          :include_entities => false
        }).and_return([
          OpenStruct.new(:id_str => @users[1].authentications.first.uid, :profile_image_url => "http://1.png"),
          OpenStruct.new(:id_str => @users[0].authentications.first.uid, :profile_image_url => "http://2.png")
        ])

        GT::UserTwitterManager.stub(:update_user_twitter_avatar).and_call_original
        GT::UserTwitterManager.stub(:update_user_twitter_avatar).with(@users[3], anything()).and_raise(exception)

        Rails.logger.stub(:info).with(any_args())
        Rails.logger.should_receive(:info).once().with("GENERAL EXCEPTION, SKIPPING RETURNED TWITTER USER #{@users[3].authentications.first.uid}: #{exception}")

        expect(GT::UserTwitterManager.update_all_twitter_avatars).to eql({
          :users_with_twitter_auth_found => 4,
          :users_with_twitter_auth_updated => 3
        })
      end

      it "logs errors outside the twitter interaction process and skips to the next shelby user" do
        MongoMapper::Plugins::IdentityMap.clear

        exception = 'hello'

        @users_route.should_receive(:lookup!).exactly(:once).with({
          :user_id => "#{@users[2].authentications.first.uid},#{@users[1].authentications.first.uid}",
          :include_entities => false
        }).and_return([
          OpenStruct.new(:id_str => @users[2].authentications.first.uid, :profile_image_url => Settings::Twitter.dummy_twitter_avatar_image_url),
          OpenStruct.new(:id_str => @users[1].authentications.first.uid, :profile_image_url => "http://somemaedupimage.png")
        ])

        i = 0
        Settings::Twitter.stub(:user_lookup_batch_size) do |arg|
          if i == 0
            i = i + 1
            raise(exception)
          else
            i = i + 1
            2
          end
        end

        Rails.logger.stub(:info).with(any_args())
        Rails.logger.should_receive(:info).once().with("GENERAL EXCEPTION, SKIPPING PROCESSING SHELBY USER #{@users[3].id}: #{exception}")

        expect(GT::UserTwitterManager.update_all_twitter_avatars).to eql({
          :users_with_twitter_auth_found => 4,
          :users_with_twitter_auth_updated => 2
        })
      end
    end

    it "falls back to a twitter client with app-wide credentials for one request at a time if user creds are not available" do
      Settings::Twitter['user_lookup_batch_size'] = 1

      user_with_twitter_oauth = Factory.create(:user)
      user_with_twitter_oauth.authentications.first.oauth_token = "token"
      user_with_twitter_oauth.authentications.first.oauth_secret = "secret"
      user_with_twitter_oauth.save

      2.times do
        user_without_twitter_oauth = Factory.create(:user)
        user_without_twitter_oauth.authentications.first.oauth_token = nil
        user_without_twitter_oauth.save
      end

      APIClients::TwitterClient.should_receive(:build_for_app).once().ordered()

      APIClients::TwitterClient.should_receive(:build_for_token_and_secret).once().ordered().with(
        "token",
        "secret"
      )

      GT::UserTwitterManager.update_all_twitter_avatars
    end

    it "doesn't keep creating app-wide credentialed clients over and over again" do
      Settings::Twitter['user_lookup_batch_size'] = 1

      @users = []
      2.times do |i|
        user_without_twitter_oauth = Factory.create(:user)
        user_without_twitter_oauth.authentications.first.oauth_token = nil
        user_without_twitter_oauth.save
        @users << user_without_twitter_oauth
      end

      MongoMapper::Plugins::IdentityMap.clear

      APIClients::TwitterClient.should_receive(:build_for_app).once()

      GT::UserTwitterManager.update_all_twitter_avatars
    end

    it "exits immediately if the app-wide twitter client has invalid twitter credentials" do
      Settings::Twitter['user_lookup_batch_size'] = 1

      @users = []
      2.times do |i|
        user_without_twitter_oauth = Factory.create(:user)
        user_without_twitter_oauth.authentications.first.oauth_token = nil
        user_without_twitter_oauth.save
        @users << user_without_twitter_oauth
      end

      MongoMapper::Plugins::IdentityMap.clear

      twitter_error = Grackle::TwitterError.new(:get, nil, 401, "{\"errors\":[{\"message\":\"Invalid or expired token\",\"code\":89}]}")
      twitter_error_struct = OpenStruct.new(:message => "Invalid or expired token", :code => 89)
      twitter_response_object = OpenStruct.new(:errors => [twitter_error_struct])
      twitter_error.should_receive(:response_object).at_least(:once).and_return(twitter_response_object)

      @users_route.should_receive(:lookup!).exactly(:once).and_raise(twitter_error)

      Rails.logger.stub(:info).with(any_args())
      Rails.logger.should_receive(:info).once().with("TWITTER REPLIED INVALID CREDENTIALS TO APP-WIDE CREDENTIALS")

      expect(GT::UserTwitterManager.update_all_twitter_avatars).to eql({
        :users_with_twitter_auth_found => 1,
        :users_with_twitter_auth_updated => 0
      })
    end

  end

end