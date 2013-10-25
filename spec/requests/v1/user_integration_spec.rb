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
          parse_json(response.body)["result"][0]["followed_at"].to_i == @u1.roll_followings[0].id.generation_time.to_i
        end

        it "should return the creator authentication info for each roll" do
          r1 = Factory.create(:roll, :creator => @u1, :roll_type => Roll::TYPES[:user_public])
          r1.add_follower(@u1)

          get '/v1/user/'+@u1.id+'/rolls/following'
          response.body.should have_json_path('result/0/creator_authentications')
          response.body.should have_json_size(1).at_path('result/0/creator_authentications')
          response.body.should have_json_path('result/0/creator_authentications/0/provider')
          response.body.should have_json_path('result/0/creator_authentications/0/uid')
          response.body.should have_json_path('result/0/creator_authentications/0/nickname')
          response.body.should have_json_path('result/0/creator_authentications/0/name')
          response.body.should be_json_eql("\"twitter\"").at_path('result/0/creator_authentications/0/provider')
          response.body.should be_json_eql("\"#{@u1.authentications[0].uid}\"").at_path('result/0/creator_authentications/0/uid')
          response.body.should be_json_eql("\"nickname\"").at_path('result/0/creator_authentications/0/nickname')
          response.body.should be_json_eql("\"name\"").at_path('result/0/creator_authentications/0/name')
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

        it "should return special_public (faux user) rolls when param include_faux is passed" do
          r1 = Factory.create(:roll, :creator => Factory.create(:user), :roll_type => Roll::TYPES[:special_public])
          r1.add_follower(@u1)
          r2 = Factory.create(:roll, :creator => Factory.create(:user), :roll_type => Roll::TYPES[:special_roll])
          r2.add_follower(@u1)

          @u1.save
          get '/v1/user/'+@u1.id+'/rolls/following?include_faux=true'
          response.body.should be_json_eql(200).at_path("status")
          parse_json(response.body)["result"].class.should eq(Array)
          response.body.should have_json_size(1).at_path('result')
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

      context "rolls/personal" do
        before(:each) do
          @r1 = Factory.create(:roll, :creator => @u1, :roll_type => Roll::TYPES[:special_public_real_user], :title => 'title')
          @u1.public_roll = @r1
          @u1.save
        end

        it "should return the user's personal roll if user id provided" do
          get '/v1/user/'+@u1.id+'/rolls/personal'
          response.body.should be_json_eql(200).at_path("status")
        end

        it "should return the user's personal roll if user nickname provided" do
          get '/v1/user/'+@u1.nickname+'/rolls/personal'
          response.body.should be_json_eql(200).at_path("status")
        end

        it "should return the user's personal roll if user nickname with non-alphanumeric characters provided" do
          @u1.nickname = 'user.name'
          @u1.save
          get '/v1/user/'+@u1.nickname+'/rolls/personal'
          response.body.should be_json_eql(200).at_path("status")
          response.body.should be_json_eql("\"user.name\"").at_path("result/creator_nickname")
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

      it "should return :creator_nickname, :creator_name, :following_user_count which are specially injected in the controller" do
        r1 = Factory.create(:roll, :creator => @u1, :roll_type => Roll::TYPES[:user_public])
        r1.add_follower(@u1)
        get '/v1/user/'+@u1.id+'/rolls/following'
        response.body.should be_json_eql(200).at_path("status")
        parse_json(response.body)["result"][0]["creator_nickname"].should == @u1.nickname
        parse_json(response.body)["result"][0]["creator_name"].should == @u1.name
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

      context "rolled_since_last_notification" do
        it "should return rolled_since_last_notification with user if the supplied user_id is the current_users" do
          get '/v1/user/' + @u1.id
          response.body.should have_json_path("result/rolled_since_last_notification")
        end

       it "should NOT return rolled_since_last_notification with user if the supplied user_id is not the current_users" do
          u2 = Factory.create(:user)
          get '/v1/user/' + u2.id
          response.body.should_not have_json_path("result/rolled_since_last_notification")
        end
      end

    end

    describe "GET dashboard" do

      context "when entries exist" do
        before(:each) do
          @v = Factory.create(:video)
          @f = Factory.create(:frame, :creator_id => @u1.id, :video => @v)
          @d = Factory.build(:dashboard_entry)
          @d.user = @u1; @d.frame = @f
          @d.save
        end

        it "should return dashboard entry on success" do
          get '/v1/user/'+@u1.id+'/dashboard'
          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result")
          parse_json(response.body)["result"][0]["frame"]["id"].should eq(@f.id.to_s)
        end

        context "other user" do
          before(:each) do
            @u2 = Factory.create(:user)
          end

          it "should return 401 unauthorized if trying to get a user other than herself" do
            get '/v1/user/'+@u2.id+'/dashboard'
            response.body.should be_json_eql(401).at_path("status")
          end

          it "should allow a user to get dashboard for another user who has a public dashboard" do
            @u2.public_dashboard = true
            get '/v1/user/'+@u2.id+'/dashboard'
            response.body.should be_json_eql(200).at_path("status")
          end

          it "should allow an admin user to get dashboard for another user" do
            @u1.is_admin = true
            get '/v1/user/'+@u2.id+'/dashboard'
            response.body.should be_json_eql(200).at_path("status")
          end

          it "should return 404 if another user is not found" do
            get '/v1/user/nonexistant/dashboard'
            response.body.should be_json_eql(404).at_path("status")
          end
        end
      end

      context 'trigger_recs param' do
        before(:each) do
          GT::VideoProviderApi.stub(:get_video_info)
        end

        it "should do a check for inserting recommendations when trigger_recs param is included" do
          GT::RecommendationManager.should_receive(:if_no_recent_recs_generate_rec)
          get '/v1/user/'+@u1.id+'/dashboard?trigger_recs=true'
        end

        it "should not do a check for inserting recommendation when the user is not the current logged in user" do
          other_user = Factory.create(:user, :public_dashboard => true)
          GT::RecommendationManager.should_not_receive(:if_no_recent_recs_generate_rec)
          get '/v1/user/'+other_user.id+'/dashboard?trigger_recs=true'
        end

        context "recs exist" do
          before(:each) do
            v = Factory.create(:video)
            @rec_vid = Factory.create(:video)
            rec = Factory.create(:recommendation, :recommended_video_id => @rec_vid.id, :score => 100.0)
            v.recs << rec
            v.save

            sharer = Factory.create(:user)
            f = Factory.create(:frame, :video => v, :creator => sharer )

            dbe = Factory.create(:dashboard_entry, :frame => f, :user => @u1, :video_id => v.id, :action => DashboardEntry::ENTRY_TYPE[:new_social_frame], :actor => sharer)
            dbe.save
          end

          it "creates a new dashboard entry" do
            MongoMapper::Plugins::IdentityMap.clear

            expect {
              get '/v1/user/'+@u1.id+'/dashboard?trigger_recs=true'
            }.to change(DashboardEntry, :count)
          end

          it "doesn't create a new dashboard entry if the video has no thumbnail" do
            @rec_vid.thumbnail_url = nil
            @rec_vid.save
            MongoMapper::Plugins::IdentityMap.clear

            expect {
              get '/v1/user/'+@u1.id+'/dashboard?trigger_recs=true'
            }.not_to change(DashboardEntry, :count)
          end
        end

        it "should not do a check for inserting recommendations when a since_id is included" do
          GT::RecommendationManager.should_not_receive(:if_no_recent_recs_generate_rec)
          get '/v1/user/'+@u1.id+'/dashboard?trigger_recs=true&since_id=someid'
        end

        it "should not do a check for inserting recommendations when trigger_recs param is not included" do
          GT::RecommendationManager.should_not_receive(:if_no_recent_recs_generate_rec)
          get '/v1/user/'+@u1.id+'/dashboard'
        end

      end

    end

    describe "GET recommendations" do
      before(:each) do
        GT::MortarHarvester.stub(:get_recs_for_user).and_return([])
        @featured_channel_user = Factory.create(:user)
        Settings::Channels['featured_channel_user_id'] = @featured_channel_user.id.to_s
      end

      it "should return user recommendations on success" do
        get '/v1/user/'+@u1.id+'/recommendations'

        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_path("result")
        response.body.should have_json_size(0).at_path("result")
      end

      it "should use video graph and mortar as sources by default" do
        GT::RecommendationManager.any_instance.should_receive(:get_recs_for_user).with({
          :sources => [DashboardEntry::ENTRY_TYPE[:video_graph_recommendation], DashboardEntry::ENTRY_TYPE[:mortar_recommendation]],
          :limits => [3,3]
        }).and_return([])
        get '/v1/user/'+@u1.id+'/recommendations'
      end

      it "should parse the source entries and get the recommendations for the corresponding sources, ignoring invalid entries" do
        GT::RecommendationManager.any_instance.should_receive(:get_recs_for_user).with({
          :sources => [DashboardEntry::ENTRY_TYPE[:video_graph_recommendation], DashboardEntry::ENTRY_TYPE[:channel_recommendation]],
          :limits => [3,3]
        }).and_return([])
        expect { get '/v1/user/'+@u1.id+'/recommendations?sources=0,31,,,fred,!,34'}.not_to raise_error
      end

      it "should pass the right parameters from the api request to the recommendation manager" do
        GT::RecommendationManager.any_instance.should_receive(:get_recs_for_user).with({
          :sources => [DashboardEntry::ENTRY_TYPE[:video_graph_recommendation]],
          :limits => [3],
          :video_graph_entries_to_scan => 20,
          :video_graph_min_score => 80.0
        }).and_return([])
        get '/v1/user/'+@u1.id+'/recommendations?min_score=80.0&scan_limit=20&sources=31'
      end

      context "other user" do
        before(:each) do
          @u2 = Factory.create(:user)
        end

        it "should return 401 unauthorized if trying to get a user other than herself" do
          get '/v1/user/'+@u2.id+'/recommendations'
          response.body.should be_json_eql(401).at_path("status")
        end

        it "should allow an admin user to get recommendations for another user" do
          @u1.is_admin = true

          get '/v1/user/'+@u2.id+'/recommendations'
          response.body.should be_json_eql(200).at_path("status")
        end

        it "should return 404 if another user is not found" do
          @u1.is_admin = true
          get '/v1/user/nonexistant/recommendations'
          response.body.should be_json_eql(404).at_path("status")
        end
      end

      describe "result contents" do
        before(:each) do
          Array.any_instance.stub(:shuffle!)
          GT::VideoProviderApi.stub(:get_video_info)

          #create a video graph rec
          v = Factory.create(:video)
          @vid_graph_recommended_vid = Factory.create(:video)
          rec = Factory.create(:recommendation, :recommended_video_id => @vid_graph_recommended_vid.id, :score => 100.0)
          v.recs << rec

          v.save

          src_frame_creator = Factory.create(:user)
          @vid_graph_src_frame = Factory.create(:frame, :video => v, :creator => src_frame_creator )

          dbe = Factory.create(:dashboard_entry, :frame => @vid_graph_src_frame, :user => @u1, :video_id => v.id, :actor => src_frame_creator)

          dbe.save

          #create a mortar rec
          @mortar_recommended_vid = Factory.create(:video)
          @mortar_src_vid = Factory.create(:video)
          @mortar_response = [{"item_id" => @mortar_recommended_vid.id.to_s, "reason_id" => @mortar_src_vid.id.to_s}]

          GT::MortarHarvester.stub(:get_recs_for_user).and_return(@mortar_response)

          #create a channel rec
          @featured_curator = Factory.create(:user)
          @upvoter = Factory.create(:user)
          @conversation = Factory.create(:conversation)
          @message = Factory.create(:message, :text => "Some interesting text", :user_id => @featured_curator.id)
          @conversation.messages << @message
          @conversation.save
          @channel_recommended_vid = Factory.create(:video)
          @community_channel_frame = Factory.create(:frame, :creator_id => @featured_curator.id, :video_id => @channel_recommended_vid.id, :conversation_id => @conversation.id, :upvoters => [@upvoter.id])
          @community_channel_dbe = Factory.create(:dashboard_entry, :user_id => @featured_channel_user.id, :frame_id => @community_channel_frame.id, :video_id => @channel_recommended_vid.id)
        end

        it "should return the right number of results in the right order" do
          MongoMapper::Plugins::IdentityMap.clear

          get '/v1/user/'+@u1.id+'/recommendations?sources=31,33,34'

          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result")
          response.body.should have_json_size(3).at_path("result")

          parsed_response = parse_json(response.body)
          parsed_response["result"].map {|dbe| dbe["video_id"]}.should == [
            @vid_graph_recommended_vid.id.to_s,
            @mortar_recommended_vid.id.to_s,
            @channel_recommended_vid.id.to_s
          ]
        end

        it "should limit the results based on the limits parameter" do
          #create another mortar rec
          recommended_vid = Factory.create(:video)
          src_vid = Factory.create(:video)
          @mortar_response << {"item_id" => recommended_vid.id.to_s, "reason_id" => src_vid.id.to_s}
          MongoMapper::Plugins::IdentityMap.clear

          get '/v1/user/'+@u1.id+'/recommendations?sources=31,33,34&limits=1,1,1'

          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result")
          response.body.should have_json_size(3).at_path("result") # if limits didn't work it would return 4 results
        end

        it "should exclude videos that are missing thumbnails" do
          @vid_graph_recommended_vid.thumbnail_url = nil
          @vid_graph_recommended_vid.save
          @mortar_recommended_vid.thumbnail_url = nil
          @mortar_recommended_vid.save
          @channel_recommended_vid.thumbnail_url = nil
          @channel_recommended_vid.save
          MongoMapper::Plugins::IdentityMap.clear

          get '/v1/user/'+@u1.id+'/recommendations?sources=31,33,34'

          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result")
          response.body.should have_json_size(0).at_path("result")
        end

        it "should return the right attributes and contents for a video graph recommendation" do
          MongoMapper::Plugins::IdentityMap.clear

          get '/v1/user/'+@u1.id+'/recommendations?sources=31'

          response.body.should have_json_path("result/0/id")
          response.body.should have_json_path("result/0/user_id")
          response.body.should have_json_path("result/0/action")
          response.body.should have_json_path("result/0/actor_id")
          response.body.should have_json_path("result/0/video_id")

          response.body.should have_json_path("result/0/frame")
          response.body.should have_json_path("result/0/frame/video")
          response.body.should have_json_type(Array).at_path("result/0/frame/upvoters")
          response.body.should have_json_size(0).at_path("result/0/frame/upvoters")

          response.body.should have_json_path("result/0/src_frame")
          response.body.should have_json_path("result/0/src_frame/id")
          response.body.should have_json_path("result/0/src_frame/creator_id")
          response.body.should have_json_path("result/0/src_frame/creator")
          response.body.should have_json_path("result/0/src_frame/creator/id")
          response.body.should have_json_path("result/0/src_frame/creator/nickname")

          parsed_response = parse_json(response.body)

          parsed_response["result"][0]["user_id"].should eq(@u1.id.to_s)
          parsed_response["result"][0]["action"].should eq(DashboardEntry::ENTRY_TYPE[:video_graph_recommendation])
          parsed_response["result"][0]["actor_id"].should eq(nil)
          parsed_response["result"][0]["video_id"].should eq(@vid_graph_recommended_vid.id.to_s)

          parsed_response["result"][0]["frame"]["video"]["id"].should eq(@vid_graph_recommended_vid.id.to_s)
          parsed_response["result"][0]["frame"]["video"]["provider_name"].should eq(@vid_graph_recommended_vid.provider_name)
          parsed_response["result"][0]["frame"]["video"]["provider_id"].should eq(@vid_graph_recommended_vid.provider_id)

          parsed_response["result"][0]["src_frame"]["id"].should eq(@vid_graph_src_frame.id.to_s)
          parsed_response["result"][0]["src_frame"]["creator_id"].should eq(@vid_graph_src_frame.creator.id.to_s)
          parsed_response["result"][0]["src_frame"]["creator"]["id"].should eq(@vid_graph_src_frame.creator.id.to_s)
          parsed_response["result"][0]["src_frame"]["creator"]["nickname"].should eq(@vid_graph_src_frame.creator.nickname)
        end

        it "should return the right attributes and contents for a mortar recommendation" do
          MongoMapper::Plugins::IdentityMap.clear

          get '/v1/user/'+@u1.id+'/recommendations?sources=33'

          response.body.should have_json_path("result/0/id")
          response.body.should have_json_path("result/0/user_id")
          response.body.should have_json_path("result/0/action")
          response.body.should have_json_path("result/0/actor_id")
          response.body.should have_json_path("result/0/video_id")

          response.body.should have_json_path("result/0/frame")
          response.body.should have_json_path("result/0/frame/video")
          response.body.should have_json_type(Array).at_path("result/0/frame/upvoters")
          response.body.should have_json_size(0).at_path("result/0/frame/upvoters")

          response.body.should have_json_path("result/0/src_video")
          response.body.should have_json_path("result/0/src_video/id")
          response.body.should have_json_path("result/0/src_video/title")

          parsed_response = parse_json(response.body)

          parsed_response["result"][0]["user_id"].should eq(@u1.id.to_s)
          parsed_response["result"][0]["action"].should eq(DashboardEntry::ENTRY_TYPE[:mortar_recommendation])
          parsed_response["result"][0]["actor_id"].should eq(nil)
          parsed_response["result"][0]["video_id"].should eq(@mortar_recommended_vid.id.to_s)

          parsed_response["result"][0]["frame"]["video"]["id"].should eq(@mortar_recommended_vid.id.to_s)
          parsed_response["result"][0]["frame"]["video"]["provider_name"].should eq(@mortar_recommended_vid.provider_name)
          parsed_response["result"][0]["frame"]["video"]["provider_id"].should eq(@mortar_recommended_vid.provider_id)

          parsed_response["result"][0]["src_video"]["id"].should eq(@mortar_src_vid.id.to_s)
          parsed_response["result"][0]["src_video"]["title"].should eq(@mortar_src_vid.title)
        end

        it "should return the right attributes and contents for a channel recommendation" do
          MongoMapper::Plugins::IdentityMap.clear

          get '/v1/user/'+@u1.id+'/recommendations?sources=34'

          response.body.should have_json_path("result/0/id")
          response.body.should have_json_path("result/0/user_id")
          response.body.should have_json_path("result/0/action")
          response.body.should have_json_path("result/0/actor_id")
          response.body.should have_json_path("result/0/video_id")

          response.body.should have_json_path("result/0/frame")
          response.body.should have_json_path("result/0/frame/video")
          response.body.should have_json_type(Array).at_path("result/0/frame/upvoters")
          response.body.should have_json_size(1).at_path("result/0/frame/upvoters")
          response.body.should have_json_path("result/0/frame/creator_id")
          response.body.should have_json_path("result/0/frame/creator")
          response.body.should have_json_path("result/0/frame/creator/id")
          response.body.should have_json_path("result/0/frame/creator/nickname")
          response.body.should have_json_path("result/0/frame/creator/name")
          response.body.should have_json_path("result/0/frame/conversation")
          response.body.should have_json_path("result/0/frame/conversation/messages")
          response.body.should have_json_size(1).at_path("result/0/frame/conversation/messages")
          response.body.should have_json_path("result/0/frame/conversation/messages/0")
          response.body.should have_json_path("result/0/frame/conversation/messages/0/text")

          parsed_response = parse_json(response.body)

          parsed_response["result"][0]["user_id"].should eq(@u1.id.to_s)
          parsed_response["result"][0]["action"].should eq(DashboardEntry::ENTRY_TYPE[:channel_recommendation])
          parsed_response["result"][0]["actor_id"].should eq(@featured_curator.id.to_s)
          parsed_response["result"][0]["video_id"].should eq(@channel_recommended_vid.id.to_s)

          parsed_response["result"][0]["frame"]["video"]["id"].should eq(@channel_recommended_vid.id.to_s)
          parsed_response["result"][0]["frame"]["video"]["provider_name"].should eq(@channel_recommended_vid.provider_name)
          parsed_response["result"][0]["frame"]["video"]["provider_id"].should eq(@channel_recommended_vid.provider_id)

          parsed_response["result"][0]["frame"]["upvoters"][0].should eq(@upvoter.id.to_s)

          parsed_response["result"][0]["frame"]["id"].should eq(@community_channel_frame.id.to_s)
          parsed_response["result"][0]["frame"]["creator_id"].should eq(@featured_curator.id.to_s)
          parsed_response["result"][0]["frame"]["creator"]["id"].should eq(@featured_curator.id.to_s)
          parsed_response["result"][0]["frame"]["creator"]["nickname"].should eq(@featured_curator.nickname)
          parsed_response["result"][0]["frame"]["creator"]["name"].should eq(@featured_curator.name)

          parsed_response["result"][0]["frame"]["conversation"]["messages"][0]["text"].should eq(@message.text)
        end

        it "should not persist any new dashboard entries, frames, or conversations to the database" do
          MongoMapper::Plugins::IdentityMap.clear

          lambda {
            get '/v1/user/'+@u1.id+'/recommendations?sources=31,33,34'
          }.should_not change { "#{DashboardEntry.count},#{Frame.count},#{Conversation.count}" }
        end

        # it "should try to fill in more mortar recommendations if video graph recommendations are not found" do
        #   GT::RecommendationManager.any_instance.stub(:get_video_graph_recs_for_user).and_return([])
        #   GT::RecommendationManager.any_instance.should_receive(:get_mortar_recs_for_user).with(6).and_return([])
        #   GT::RecommendationManager.any_instance.should_receive(:get_channel_recs_for_user).with(@featured_channel_user.id.to_s, 3).and_return([])
        #   get '/v1/user/'+@u1.id+'/recommendations?sources=31,33,34'
        # end

      end
    end

    describe "GET stats" do
      it "should return user stats on success" do
        roll = Factory.create(:roll, :creator => @u1)
        @u1.public_roll = roll
        get '/v1/user/'+@u1.id+'/stats'

        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_path("result")
        response.body.should have_json_size(0).at_path("result")
      end

      context "other user" do
        before(:each) do
          @u2 = Factory.create(:user)
          roll = Factory.create(:roll, :creator => @u2)
          @u2.public_roll = roll
        end

        it "should return 401 unauthorized if trying to get a user other than herself" do
          get '/v1/user/'+@u2.id+'/stats'
          response.body.should be_json_eql(401).at_path("status")
        end

        it "should allow an admin user to get stats for another user" do
          @u1.is_admin = true

          get '/v1/user/'+@u2.id+'/stats'
          response.body.should be_json_eql(200).at_path("status")
        end

        it "should return 404 if another user is not found" do
          @u1.is_admin = true
          get '/v1/user/nonexistant/stats'
          response.body.should be_json_eql(404).at_path("status")
        end

      end

      describe "result contents" do

        before(:each) do
          @user_personal_roll = Factory.create(:roll, :creator => @u1)
          @u1.public_roll = @user_personal_roll
          @frame1 = Factory.create(:frame, :roll => @user_personal_roll, :creator => @u1, :like_count => 3, :view_count => 4)
          @frame2 = Factory.create(:frame, :roll => @user_personal_roll, :creator => @u1, :like_count => 1, :view_count => 10)
          @frame3 = Factory.create(:frame, :roll => @user_personal_roll, :creator => @u1, :like_count => 4, :view_count => 6)
          @video = Factory.create(:video, :view_count => 20)
          @frame1.video = @video
          @frame2.video = @video
          @frame3.video = @video
        end

        it "should return the right number of results" do
          get '/v1/user/'+@u1.id+'/stats'

          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result")
          response.body.should have_json_size(3).at_path("result")
        end

        it "should return the right number of results when num_frames param is included" do
          get '/v1/user/'+@u1.id+'/stats?num_frames=1'

          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result")
          response.body.should have_json_size(1).at_path("result")
        end

        it "should return the right frame attributes" do
          get '/v1/user/'+@u1.id+'/stats'

          response.body.should have_json_path("result/0/frame")
          response.body.should have_json_path("result/0/frame/id")
          response.body.should have_json_path("result/0/frame/like_count")
          response.body.should have_json_path("result/0/frame/view_count")
          response.body.should have_json_path("result/0/frame/roll_id")
          parse_json(response.body)["result"][0]["frame"]["id"].should eq(@frame3.id.to_s)
          parse_json(response.body)["result"][0]["frame"]["like_count"].should eq(@frame3.like_count)
          parse_json(response.body)["result"][0]["frame"]["view_count"].should eq(@frame3.view_count)
          parse_json(response.body)["result"][0]["frame"]["roll_id"].should eq(@user_personal_roll.id.to_s)
        end

        it "should return the right frame creator attributes" do
          @u1.user_image_original = 'image.jpg'
          get '/v1/user/'+@u1.id+'/stats'

          response.body.should have_json_path("result/0/frame/creator")
          response.body.should have_json_path("result/0/frame/creator/shelby_user_image")
          parse_json(response.body)["result"][0]["frame"]["creator"]["shelby_user_image"].should eq('image.jpg')
        end

        it "should return the right nested video attributes" do
          get '/v1/user/'+@u1.id+'/stats'

          response.body.should have_json_path("result/0/frame/video")
          response.body.should have_json_path("result/0/frame/video/view_count")
          parse_json(response.body)["result"][0]["frame"]["video"]["view_count"].should eq(@video.view_count)
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

      it "should return an error if nickname is already taken" do
        u2 = Factory.create(:user)
        put '/v1/user/'+@u1.id+'?nickname='+u2.nickname
        response.body.should be_json_eql(409).at_path("status")
        response.body.should have_json_path("errors/user/nickname")
        response.body.should be_json_eql("\"has already been taken\"").at_path("errors/user/nickname")
      end

      it "should return an error if email is already taken" do
        u2 = Factory.create(:user)
        put '/v1/user/'+@u1.id+'?primary_email='+u2.primary_email
        response.body.should be_json_eql(409).at_path("status")
        response.body.should have_json_path("errors/user/primary_email")
        response.body.should be_json_eql("\"has already been taken\"").at_path("errors/user/primary_email")
      end

      it "should return an error if email is not a valid address" do
        put '/v1/user/'+@u1.id+'?primary_email=d@g'
        response.body.should be_json_eql(409).at_path("status")
        response.body.should have_json_path("errors/user/primary_email")
        response.body.should include_json("\"is invalid\"").at_path("errors/user/primary_email")
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
        u2 = Factory.create(:user, :user_type => User::USER_TYPE[:faux])
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
        u2.user_type.should_not == User::USER_TYPE[:faux]
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

      it "will return error if user id is not the current_user" do
        put "/v1/user/A1/visit"
        response.body.should be_json_eql(404).at_path("status")
      end

      it "should increment user session count by 1" do
        lambda {
          put "/v1/user/#{@u1.id.to_s}/visit"
          response.body.should be_json_eql(200).at_path("status")
        }.should change {@u1.reload.session_count}.by(1)
      end

      it "should increment user's iOS session count by 1" do
        lambda {
          put "/v1/user/#{@u1.id.to_s}/visit?platform=ios"
          response.body.should be_json_eql(200).at_path("status")
        }.should change {@u1.reload.ios_session_count}.by(1)
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

    describe "GET dashboard" do

      it "should return 401 unauthorized if trying to get a user whose dashboard is not public`" do
        u = Factory.create(:user)
        get '/v1/user/'+u.id+'/dashboard'
        response.body.should be_json_eql(401).at_path("status")
      end

      it "should return success if trying to get a user who has a public dashboard" do
        u = Factory.create(:user, :public_dashboard => true)
        get '/v1/user/'+u.id+'/dashboard'
        response.body.should be_json_eql(200).at_path("status")
      end

      it "should return 404 if another user is not found" do
        get '/v1/user/nonexistant/dashboard'
        response.body.should be_json_eql(404).at_path("status")
      end

    end

    describe "GET recommendations" do

      it "should return 401 unauthorized" do
        u = Factory.create(:user)
        get '/v1/user/'+u.id+'/recommendations'
        response.status.should eq(401)
      end

    end

    describe "GET stats" do
      it "should not be able to get user stats" do
        u = Factory.create(:user)
        get '/v1/user/'+u.id+'/stats'
        response.status.should eq(401)
      end
    end

    describe "PUT" do
      it "should not be able to update user info" do
        u = Factory.create(:user)
        put '/v1/user/'+u.id+'?nickname=nick'
        response.status.should eq(401)
      end
    end

    describe "POST create" do
      it "should create a new user and return via JSON" do
        post '/v1/user', :user => { :name => "some name",
                                    :nickname => Factory.next(:nickname),
                                    :primary_email => Factory.next(:primary_email),
                                    :password => "pass" }
        response.status.should == 200
        response.body.should have_json_path("result/name")
        response.body.should have_json_path("result/nickname")
        response.body.should have_json_path("result/personal_roll_id")
        response.body.should have_json_path("result/authentication_token")
      end

      it "should fail to create bad user and return errors via JSON" do
        u1 = Factory.create(:user)

        post '/v1/user', :user => { :name => "some name",
                                    :nickname => u1.nickname,
                                    :primary_email => u1.primary_email,
                                    :password => "pass" }
        response.status.should == 409
        response.body.should have_json_path("errors/user/nickname")
        response.body.should have_json_path("errors/user/primary_email")
      end
    end

    describe "POST add dashboard entry for user" do
      before(:each) do
        @u1 = Factory.create(:user)
        set_omniauth(:uuid => @u1.authentications.first.uid)
        get '/auth/twitter/callback'
        @f =  Factory.create(:frame, :video => Factory.create(:video))
      end

      it "returns 404 in no frame is found" do
        post '/v1/user/'+@u1.id+'/dashboard_entry?frame_id=test'
        response.status.should == 404
      end

      it "returns 404 in no user is found" do
        post '/v1/user/test/dashboard_entry?frame_id='+@f.id
        response.status.should == 404
      end

      it "should return 200 if alls hunky dory" do
        post '/v1/user/'+@u1.id+'/dashboard_entry?frame_id='+@f.id
        response.status.should == 200
      end

      it "should create a dbe that has the frame as part of it" do
        post '/v1/user/'+@u1.id+'/dashboard_entry?frame_id='+@f.id
        response.body.should have_json_path("result/frame")
      end

      it "shoudl create a dbe with a frame that was specified as a param" do
        post '/v1/user/'+@u1.id+'/dashboard_entry?frame_id='+@f.id
        parse_json(response.body)["result"]["frame"]['id'].should eq(@f.id.to_s)
      end
    end

  end

end
