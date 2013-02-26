require 'spec_helper'

describe 'v1/user' do

  context 'logged in' do
    before(:each) do
      @u1 = Factory.create(:user)
      set_omniauth(:uuid => @u1.authentications.first.uid)
      get '/auth/twitter/callback'
    end

    describe "GET index" do

      context "no ids param - lookup current user" do

        it "should return user info on success" do
          get '/v1/user'
          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result/nickname")
          response.body.should have_json_path("result/has_password")
        end

        it "should return cohorts with user" do
          @u1.cohorts = ["a", "b"]
          @u1.save

          get '/v1/user'
          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_size(2).at_path("result/cohorts")
          response.body.should be_json_eql(["a", "b"]).at_path("result/cohorts")
        end

        it "should have a user app progress attr" do
          get '/v1/user'
          response.body.should have_json_path("result/app_progress")
        end

        it "should not have a roll_followings attr" do
          get '/v1/user'
          response.body.should_not have_json_path("result/roll_followings")
        end

        it "should return correct personal_roll_subdomain attribute" do
          r1 = Factory.create(:roll, :creator => @u1, :roll_type => Roll::TYPES[:special_public_real_user], :title => 'title')
          @u1.public_roll = r1
          @u1.save

          get '/v1/user'
          response.body.should have_json_path("result/personal_roll_subdomain")
          parse_json(response.body)["result"]["personal_roll_subdomain"].should == "title"
        end

        it "should return twitter_uid attribute" do
          get '/v1/user'
          response.body.should have_json_path("result/twitter_uid")
          parse_json(response.body)["result"]["twitter_uid"].should == @u1.authentications.first.uid
        end

        it "should return website attribute" do
          @u1.website = 'www.example.com'
          get '/v1/user'
          response.body.should have_json_path("result/website")
          parse_json(response.body)["result"]["website"].should == @u1.website
        end

        it "should return dot_tv_description attribute" do
          @u1.dot_tv_description = 'Welcome to my .tv'
          get '/v1/user'
          response.body.should have_json_path("result/dot_tv_description")
          parse_json(response.body)["result"]["dot_tv_description"].should == @u1.dot_tv_description
        end

        it "should wrap with callback when requesting via jsonp" do
          get '/v1/user/?callback=jQuery17108599677098863208_1335973680689&include_rolls=true&_=1335973682178'
          response.body.should =~ /^\W*jQuery17108599677098863208_1335973680689/
        end

      end

      context "ids param supplied" do

        it "should return 200 on success for single user" do
          get "/v1/user?ids=#{@u1.id.to_s}"
          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_size(1).at_path("result")
        end

        it "should return empty array if nothing found matching ids" do
          get "/v1/user?ids=some_nonexistant_id"
          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_size(0).at_path("result")
        end

      end

    end

    describe "GET show" do

      it "should return user info for another user besides herself" do
        u2 = Factory.create(:user)
        get '/v1/user/'+u2.id
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_path("result/nickname")
      end

      it "should return correct personal_roll_subdomain attribute for another user" do
        u2 = Factory.create(:user)
        r1 = Factory.create(:roll, :creator => u2, :roll_type => Roll::TYPES[:special_public_real_user], :title => 'user_name')
        u2.public_roll = r1
        u2.save

        get '/v1/user/'+u2.id
        response.body.should have_json_path("result/personal_roll_subdomain")
        parse_json(response.body)["result"]["personal_roll_subdomain"].should == "user-name"
      end

      it "should return website attribute for another user" do
        u2 = Factory.create(:user)
        u2.website = 'www.example.com'
        get '/v1/user/'+u2.id
        response.body.should have_json_path("result/website")
        parse_json(response.body)["result"]["website"].should == u2.website
      end

      it "should return dot_tv_description attribute for another user" do
        u2 = Factory.create(:user)
        u2.dot_tv_description = 'Welcome to my .tv'
        get '/v1/user/'+u2.id
        response.body.should have_json_path("result/dot_tv_description")
        parse_json(response.body)["result"]["dot_tv_description"].should == u2.dot_tv_description
      end

      it "should get a user by querying by nickname" do
        u2 = Factory.create(:user)
        u2.downcase_nickname = u2.nickname.downcase
        u2.save
        get '/v1/user/'+u2.nickname
        response.body.should be_json_eql(200).at_path("status")
        parse_json(response.body)["result"]["nickname"].should eq(u2.nickname)
      end

      it "should show user is logged in" do
        get '/v1/signed_in'
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_path("result/signed_in")
        parse_json(response.body)["result"]["signed_in"].should eq(true)
      end

      context "rolls/following" do
        it "should show a users roll followings if the supplied user_id is the current_users" do
          r1 = Factory.create(:roll, :creator => @u1, :roll_type => Roll::TYPES[:user_public])
          r1.add_follower(@u1)
          r2 = Factory.create(:roll, :creator => @u1, :roll_type => Roll::TYPES[:user_public])
          r2.add_follower(@u1)

          get '/v1/user/'+@u1.id+'/rolls/following'
          response.body.should be_json_eql(200).at_path("status")
          parse_json(response.body)["result"].class.should eq(Array)
          response.body.should have_json_size(2).at_path('result')
          #most recently followed roll is returned first
          parse_json(response.body)["result"][0]["id"].should == r2.id.to_s
          parse_json(response.body)["result"][0]["followed_at"].should == @u1.roll_followings[0].id.generation_time.to_f
        end

        it "should not return special_roll or special_public rolls (since they come from faux users)" do
          r1 = Factory.create(:roll, :creator => Factory.create(:user), :roll_type => Roll::TYPES[:special_public])
          r1.add_follower(@u1)
          r2 = Factory.create(:roll, :creator => Factory.create(:user), :roll_type => Roll::TYPES[:special_roll])
          r2.add_follower(@u1)

          @u1.save
          get '/v1/user/'+@u1.id+'/rolls/following'
          response.body.should be_json_eql(200).at_path("status")
          parse_json(response.body)["result"].class.should eq(Array)
          response.body.should have_json_size(0).at_path('result')
        end

        it "should return special_public_real_user rolls" do
          r1 = Factory.create(:roll, :creator => Factory.create(:user), :roll_type => Roll::TYPES[:special_public_real_user])
          r1.add_follower(@u1)

          @u1.save
          get '/v1/user/'+@u1.id+'/rolls/following'
          response.body.should be_json_eql(200).at_path("status")
          parse_json(response.body)["result"].class.should eq(Array)
          response.body.should have_json_size(1).at_path('result')
          parse_json(response.body)["result"][0]["id"].should == r1.id.to_s
          parse_json(response.body)["result"][0]["followed_at"].should == @u1.roll_followings[0].id.generation_time.to_f
        end

        it "should return special_public_upgraded rolls" do
          r1 = Factory.create(:roll, :creator => Factory.create(:user), :roll_type => Roll::TYPES[:special_public_upgraded])
          r1.add_follower(@u1)

          @u1.save
          get '/v1/user/'+@u1.id+'/rolls/following'
          response.body.should be_json_eql(200).at_path("status")
          parse_json(response.body)["result"].class.should eq(Array)
          response.body.should have_json_size(1).at_path('result')
          parse_json(response.body)["result"][0]["id"].should == r1.id.to_s
          parse_json(response.body)["result"][0]["followed_at"].should == @u1.roll_followings[0].id.generation_time.to_f
        end

        it "should not show a users rolls if the supplied user_id is NOT the current_users" do
          u2 = Factory.create(:user)
          get '/v1/user/'+u2.id+'/rolls/following'
          response.body.should be_json_eql(403).at_path("status")
        end

        it "should return rolls in followed_at descending order" do
          r0 = Factory.create(:roll, :creator => @u1, :roll_type => Roll::TYPES[:user_public])
          r0.add_follower(@u1)
          r1 = Factory.create(:roll, :creator => @u1, :roll_type => Roll::TYPES[:user_public])
          r1.add_follower(@u1)
          r2 = Factory.create(:roll, :creator => @u1, :roll_type => Roll::TYPES[:user_public])
          r2.add_follower(@u1)

          #adjust the roll followings id which in turn is used as creation time
          @u1.roll_following_for(r1).update_attribute(:_id, BSON::ObjectId.from_time(50.days.ago))
          @u1.roll_following_for(r2).update_attribute(:_id, BSON::ObjectId.from_time(10.days.ago))
          @u1.roll_following_for(r0).update_attribute(:_id, BSON::ObjectId.from_time(1.days.ago))
          @u1.save

          get '/v1/user/'+@u1.id+'/rolls/following'
          response.body.should be_json_eql(200).at_path("status")
          parse_json(response.body)["result"].class.should eq(Array)
          parse_json(response.body)["result"][0]["id"].should == r0.id.to_s
          parse_json(response.body)["result"][1]["id"].should == r2.id.to_s
          parse_json(response.body)["result"][2]["id"].should == r1.id.to_s
        end

        it "should have the first three rolls be mine, hearts, watch later" do
          r0 = Factory.create(:roll, :creator => @u1, :roll_type => Roll::TYPES[:user_public])
          r0.add_follower(@u1)
          wl_roll = Factory.create(:roll, :creator => @u1, :roll_type => Roll::TYPES[:special_watch_later])
          wl_roll.add_follower(@u1)
          public_roll = Factory.create(:roll, :creator => @u1, :roll_type => Roll::TYPES[:special_public_real_user])
          public_roll.add_follower(@u1)
          hearts_roll = Factory.create(:roll, :creator => @u1, :roll_type => Roll::TYPES[:special_upvoted])
          hearts_roll.add_follower(@u1)
          r3 = Factory.create(:roll, :creator => @u1)
          r3.add_follower(@u1)
          @u1.public_roll = public_roll
          @u1.upvoted_roll = hearts_roll
          @u1.watch_later_roll = wl_roll
          @u1.save

          get '/v1/user/'+@u1.id+'/rolls/following'
          parse_json(response.body)["result"][0]["id"].should == public_roll.id.to_s
          parse_json(response.body)["result"][0]["roll_type"].should == public_roll.roll_type
          #no longer returning hearts roll
          parse_json(response.body)["result"][1]["id"].should == wl_roll.id.to_s
        end
      end

      context "rolls/postable" do
        it "should only return the subset of rolls that the user can post to" do
          public_roll = Factory.create(:roll, :creator => @u1, :collaborative => false, :roll_type => Roll::TYPES[:special_public_real_user])
          public_roll.add_follower(@u1)
          @u1.public_roll = public_roll
          @u1.save

          upvoted_roll = Factory.create(:roll, :creator => @u1, :collaborative => false, :roll_type => Roll::TYPES[:special_upvoted])
          upvoted_roll.add_follower(@u1)
          @u1.upvoted_roll = upvoted_roll
          @u1.save

          r1 = Factory.create(:roll, :creator => @u1, :roll_type => Roll::TYPES[:special_public_real_user])
          r1.add_follower(@u1)
          r2 = Factory.create(:roll, :creator => Factory.create(:user), :public => false, :collaborative => true, :roll_type => Roll::TYPES[:user_public])
          r2.add_follower(@u1)
          r3 = Factory.create(:roll, :creator => Factory.create(:user), :public => true, :collaborative => false, :roll_type => Roll::TYPES[:user_public])
          r3.add_follower(@u1)

          @u1.save

          get '/v1/user/'+@u1.id+'/rolls/postable'
          response.body.should have_json_size(3).at_path("result")
          parse_json(response.body)["result"][0]["id"].should == public_roll.id.to_s
          #no longer returning hearts roll
          parse_json(response.body)["result"][1]["id"].should == r2.id.to_s
          parse_json(response.body)["result"][2]["id"].should == r1.id.to_s
        end
      end

      it "should return frames if they are asked for in roll followings" do
        url = 'http://url.here'
        r1 = Factory.create(:roll, :creator => @u1, :first_frame_thumbnail_url => url, :roll_type => Roll::TYPES[:user_public])
        r1.add_follower(@u1)
        get '/v1/user/'+@u1.id+'/rolls/following'
        response.body.should be_json_eql(200).at_path("status")
        parse_json(response.body)["result"][0]["first_frame_thumbnail_url"].should eq(url)
      end

      it "should have correct watch_later and public roll ids returned" do
        @u1.watch_later_roll_id = 12345
        @u1.public_roll_id = 54321
        @u1.save
        get '/v1/user/'+@u1.id
        parse_json(response.body)["result"]["watch_later_roll_id"].should eq(@u1.watch_later_roll_id)
        parse_json(response.body)["result"]["personal_roll_id"].should eq(@u1.public_roll_id)
      end

      it "should return :creator_nickname, :following_user_count which are specially injected in the controller" do
        r1 = Factory.create(:roll, :creator => @u1, :roll_type => Roll::TYPES[:user_public])
        r1.add_follower(@u1)
        get '/v1/user/'+@u1.id+'/rolls/following'
        response.body.should be_json_eql(200).at_path("status")
        parse_json(response.body)["result"][0]["creator_nickname"].should == @u1.nickname
        parse_json(response.body)["result"][0]["following_user_count"].should == 1
      end

      context "valid_token route" do

        it "should render an error if user doen't have the specified authentication" do
          get '/v1/user/'+@u1.id+'/is_token_valid?provider=facebook'
          response.body.should be_json_eql(404).at_path("status")
        end

        it "should return error if a provider is not specified or is not supporte" do
          get '/v1/user/'+@u1.id+'/is_token_valid'
          response.body.should be_json_eql(404).at_path("status")

          get '/v1/user/'+@u1.id+'/is_token_valid?provider=funckymoney'
          response.body.should be_json_eql(404).at_path("status")
        end
      end

      context "autocomplete" do
        it "should return autocomplete info with user if the supplied user_id is the current_users" do
          get '/v1/user/' + @u1.id
          response.body.should have_json_path("result/autocomplete")
        end

       it "should NOT return autocomplete info with user if the supplied user_id is not the current_users" do
          u2 = Factory.create(:user)
          get '/v1/user/' + u2.id
          response.body.should_not have_json_path("result/autocomplete")
        end
      end

    end

    describe "PUT" do
      it "should return user info on success" do
        put '/v1/user/'+@u1.id+'?name=Barack%20Obama'
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_path("result/name")
        parse_json(response.body)["result"]["name"].should eq("Barack Obama")
      end

      it "should return correct personal_roll_subdomain attribute on success" do
        r1 = Factory.create(:roll, :creator => @u1, :roll_type => Roll::TYPES[:special_public_real_user], :title => 'title1')
        @u1.public_roll = r1
        @u1.save

        put '/v1/user/'+@u1.id+'?name=Barack%20Obama'
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_path("result/personal_roll_subdomain")
        parse_json(response.body)["result"]["personal_roll_subdomain"].should == "title1"
      end

      it "should return an error if nickname validation fails" do
        u2 = Factory.create(:user)
        put '/v1/user/'+@u1.id+'?nickname='+u2.nickname
        response.body.should be_json_eql(409).at_path("status")
        response.body.should have_json_path("errors/user/nickname")
      end

      it "should return an error if email validation fails" do
        u2 = Factory.create(:user)
        put '/v1/user/'+@u1.id+'?primary_email='+u2.primary_email
        response.body.should be_json_eql(409).at_path("status")
        response.body.should have_json_path("errors/user/primary_email")
      end

      it "should update a users app_progress successfuly" do
        put '/v1/user/'+@u1.id+'?app_progress[test]=2'
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_path("result/app_progress")
        parse_json(response.body)["result"]["app_progress"]["test"].should eq("2")
      end

      it "should update nickname and that should be reflected in new downcase_nickname" do
        new_nick = "WhAtaintUniQUE--123"
        lambda {
          put "/v1/user/#{@u1.id}?nickname=#{new_nick}"
        }.should change { @u1.reload.nickname }
        response.body.should be_json_eql(200).at_path("status")
        @u1.reload.downcase_nickname.should == new_nick.downcase
      end

      it "shuld allow you to take the nickname of a faux user" do
        u2 = Factory.create(:user, :faux => User::FAUX_STATUS[:true])
        new_nick = u2.nickname
        lambda {
          put "/v1/user/#{@u1.id}?nickname=#{new_nick}"
        }.should change { @u1.reload.nickname }
        response.body.should be_json_eql(200).at_path("status")
        @u1.reload.downcase_nickname.should == new_nick.downcase
        u2.reload.nickname.should_not == new_nick
      end

      it "should return 409 if another *real* user has the proposed nickname" do
        u2 = Factory.create(:user)
        u2.gt_enable!
        u2.faux.should_not == User::FAUX_STATUS[:true]
        new_nick = u2.nickname
        lambda {
          put "/v1/user/#{@u1.id}?nickname=#{new_nick}"
        }.should_not change { @u1.reload.nickname }
        response.body.should be_json_eql(409).at_path("status")
      end

      it "should update the user's public_roll title when changing the user nickname if the roll has nickname as its title" do
        roll = Factory.build(:roll, :title => @u1.nickname)
        roll.creator = @u1
        roll.save
        @u1.public_roll = roll
        @u1.save
        put '/v1/user/'+@u1.id+'?nickname=pharoah'
        @u1.reload
        @u1.public_roll.title.should == "pharoah"
      end

      it "should not change password if password isn't sent" do
        lambda {
          put '/v1/user/'+@u1.id
          response.body.should be_json_eql(200).at_path("status")
        }.should_not change { @u1.encrypted_password }
      end

      it "should not change the password if the confirmation doesn't match" do
        pass = "the_new-PASS"
        lambda {
          put "/v1/user/#{@u1.id}?password=#{pass}&password_confirmation=WRONG"
          response.body.should be_json_eql(409).at_path("status")
        }.should_not change { @u1.encrypted_password }
      end

      it "should change password if password and password_confirmation are sent" do
        pass = "the_new-PASS"
        lambda {
          put "/v1/user/#{@u1.id}?password=#{pass}&password_confirmation=#{pass}"
          response.body.should be_json_eql(200).at_path("status")
          response.body.should_not have_json_path("result/password")
          response.body.should_not have_json_path("result/password_confirmation")
          response.body.should_not have_json_path("result/encrypted_password")
        }.should change { @u1.reload.encrypted_password }
        @u1.reload.valid_password?(pass).should == true
      end

      context "invite accepted notification" do

        context "user was invited by someone" do
          before(:each) do
            @inviter = Factory.create(:user) #sets a primary_email on user
            @inviter.save
            beta_invite = BetaInvite.new(:to_email_address => @u1.primary_email)
            beta_invite.invitee = @u1
            beta_invite.sender = @inviter
            beta_invite.save
          end

          it "should send an invite accepted notification if user completes onboarding" do
            GT::NotificationManager.should_receive(:check_and_send_invite_accepted_notification).with(@inviter, @u1).and_return(nil)
            put "/v1/user/#{@u1.id}", :app_progress => { :onboarding => 4 }
            response.body.should be_json_eql(200).at_path("status")
          end

          it "should NOT send an invite accepted notification if user did not complete onboarding" do
            GT::NotificationManager.should_not_receive(:check_and_send_invite_accepted_notification)
            put "/v1/user/#{@u1.id}", :name => 'Some New Name'
            response.body.should be_json_eql(200).at_path("status")
          end

          it "should NOT send an invite accepted notification if user completed onboarding for 2nd+ time" do
            @u1.app_progress = AppProgress.new(:onboarding => 4)
            @u1.save
            GT::NotificationManager.should_not_receive(:check_and_send_invite_accepted_notification)
            put "/v1/user/#{@u1.id}", :app_progress => { :onboarding => 4 }
            response.body.should be_json_eql(200).at_path("status")
          end

        end

        context "user was not invited by someone" do
          it "should NOT send an invite accepted notification" do
            GT::NotificationManager.should_not_receive(:check_and_send_invite_accepted_notification)
            put "/v1/user/#{@u1.id}", :app_progress => { :onboarding => 4 }
            response.body.should be_json_eql(200).at_path("status")
          end
        end

      end

    end
  end

  context "not logged in" do

    context "GET index" do
      before(:each) do
        @u1 = Factory.create(:user)
        @u2 = Factory.create(:user)
      end

      it "should return 200 on success for single user" do
        get "/v1/user?ids=#{@u1.id.to_s}"
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_size(1).at_path("result")
      end

      it "should contain all necessary attributes" do
        get "/v1/user?ids=#{@u1.id.to_s}"
        response.body.should have_json_path("result/0")
        response.body.should have_json_path("result/0/id")
        response.body.should have_json_path("result/0/name")
        response.body.should have_json_path("result/0/has_shelby_avatar")
        response.body.should have_json_path("result/0/avatar_updated_at")
        response.body.should have_json_path("result/0/user_image")
        response.body.should have_json_path("result/0/user_image_original")
      end

      it "should not contain private attributes like primary email" do
        get "/v1/user?ids=#{@u1.id.to_s}"
        response.body.should have_json_path("result/0")
        response.body.should_not have_json_path("result/0/primary_email")
      end

      it "should return 200 on success for multiple users" do
        get "/v1/user?ids=#{@u1.id.to_s},#{@u2.id.to_s}"
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_size(2).at_path("result")
      end

      it "should only return as many users as it can find" do
        get "/v1/user?ids=#{@u1.id.to_s},#{@u1.id.to_s},,,some_nonexistant_id"
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_size(1).at_path("result")
      end

      it "should return empty array if nothing found" do
        get "/v1/user?ids=some_nonexistant_id"
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_size(0).at_path("result")
      end

      it "should return 401 if ids param not included" do
        get '/v1/user'
        response.body.should be_json_eql(401).at_path("status")
        response.body.should have_json_path("message")
        parse_json(response.body)["message"].should eq("current user not authenticated")
      end

      it "should return 400 if too many ids included" do

        get "/v1/user?ids=#{(1..11).to_a.join(',')}"
        response.body.should be_json_eql(400).at_path("status")
        response.body.should have_json_path("message")
        parse_json(response.body)["message"].should eq("too many ids included (max 10)")
      end
    end

    describe "GET show" do
      it "should return user if a user is found" do
        u = Factory.create(:user)
        get '/v1/user/'+u.id
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_path("result/nickname")
      end

      it "should return an error if a user is not found" do
        get '/v1/user'
        response.body.should have_json_type(Integer).at_path("status")
        response.body.should be_json_eql(401).at_path("status")
      end

      it "should show user is logged in" do
        get '/v1/signed_in'
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_path("result/signed_in")
        parse_json(response.body)["result"]["signed_in"].should eq(false)
      end

      it "should return error if trying to get a users rolls" do
        u = Factory.create(:user)
        get '/v1/user/'+u.id+'/rolls/following'
        response.body.should be_json_eql(401).at_path("status")
      end

    end

    describe "PUT" do
      it "should not be able to update user info" do
        u = Factory.create(:user)
        put '/v1/user/'+u.id+'?nickname=nick'
        response.status.should eq(401)
      end
    end
  end

end
