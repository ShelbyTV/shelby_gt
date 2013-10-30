require 'spec_helper'

describe 'v1/dashboard' do
  context 'logged in' do
    before(:each) do
      @u1 = Factory.create(:user)
      set_omniauth(:uuid => @u1.authentications.first.uid)
      get '/auth/twitter/callback'
    end

    describe "GET" do
      context "when entries exist" do
        before(:each) do
          @v = Factory.create(:video)
          @f = Factory.create(:frame, :creator_id => @u1.id, :video => @v)
          @d = Factory.build(:dashboard_entry)
          @d.user = @u1; @d.frame = @f
          @d.save
        end

        it "should return dashboard entry on success" do
          get '/v1/dashboard'
          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result")
          parse_json(response.body)["result"][0]["frame"]["id"].should eq(@f.id.to_s)
        end

        it "should contain frame upvoters" do
          get '/v1/dashboard'
          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_type(Array).at_path("result/0/frame/upvoters")
          response.body.should have_json_size(0).at_path("result/0/frame/upvoters")
        end

        it "should populate frame upvoters with correct data" do
          upvoter1 = Factory.create(:user)
          upvoter2 = Factory.create(:user)
          @f.upvoters << upvoter1.id << upvoter2.id
          @f.save
          get '/v1/dashboard'

          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_size(2).at_path("result/0/frame/upvoters")
          parse_json(response.body)["result"][0]["frame"]["upvoters"][0].should eq(upvoter1.id.to_s)
        end

        it "should contain frame like_count" do
          get '/v1/dashboard'
          response.body.should have_json_path("result/0/frame/like_count")
          response.body.should have_json_type(Integer).at_path("result/0/frame/like_count")
          parse_json(response.body)["result"][0]["frame"]["like_count"].should eq(0)
        end

        it "should populate frame like_count with correct data" do
          @f.like_count = 2
          @f.save

          get '/v1/dashboard'
          parse_json(response.body)["result"][0]["frame"]["like_count"].should eq(2)
        end

        it "should return an empty array when there are no video recommendations" do
          get '/v1/dashboard'
          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result")
          response.body.should have_json_size(0).at_path("result/0/frame/video/recs")
        end

        it "should return a non-empty array when there are video recommendations" do
          @rv = Factory.create(:video)
          @r = Factory.create(:recommendation, :recommended_video_id => @rv.id)
          @v.recs << @r
          @v.save
          MongoMapper::Plugins::IdentityMap.clear

          get '/v1/dashboard'
          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result")
          response.body.should have_json_size(1).at_path("result/0/frame/video/recs")
          parse_json(response.body)["result"][0]["frame"]["video"]["recs"][0]["recommended_video_id"].should eq(@rv.id.to_s)
        end

        it "should not return the src_frame when there isn't one" do
          get '/v1/dashboard'

          response.body.should_not have_json_path("result/0/src_frame")
        end

        it "should return the src_frame sub-object when there is one" do
          creator = Factory.create(:user)
          src_frame = Factory.create(:frame, :creator => creator)
          @d.src_frame = src_frame
          @d.save

          get '/v1/dashboard'

          response.body.should have_json_path("result/0/src_frame")
          response.body.should have_json_path("result/0/src_frame/id")
          response.body.should have_json_path("result/0/src_frame/creator/id")
          response.body.should have_json_path("result/0/src_frame/creator/nickname")

          parsed_response = parse_json(response.body)
          parsed_response["result"][0]["src_frame"]["id"].should eq(src_frame.id.to_s)
          parsed_response["result"][0]["src_frame"]["creator"]["id"].should eq(creator.id.to_s)
          parsed_response["result"][0]["src_frame"]["creator"]["nickname"].should eq(creator.nickname)
        end

        it "should not return the src_video when there isn't one" do
          get '/v1/dashboard'

          response.body.should_not have_json_path("result/0/src_video")
        end

        it "should return the src_video sub object when there is one" do
          src_video = Factory.create(:video)
          @d.src_video = src_video
          @d.save

          get '/v1/dashboard'

          response.body.should have_json_path("result/0/src_video")
          response.body.should have_json_path("result/0/src_video/id")
          response.body.should have_json_path("result/0/src_video/title")

          parsed_response = parse_json(response.body)
          parsed_response["result"][0]["src_video"]["id"].should eq(src_video.id.to_s)
          parsed_response["result"][0]["src_video"]["title"].should eq(src_video.title)
        end

        it "should return the friend arrays when the entry is an entertainment graph recommendation" do
          friend_user_id_string1 = Factory.create(:user).id.to_s
          friend_user_id_string2 = Factory.create(:user).id.to_s
          friend_user_id_string3 = Factory.create(:user).id.to_s
          friend_user_id_string4 = Factory.create(:user).id.to_s
          friend_user_id_string5 = Factory.create(:user).id.to_s
          @d.action = DashboardEntry::ENTRY_TYPE[:entertainment_graph_recommendation]
          @d.friend_sharers_array = [friend_user_id_string1]
          @d.friend_viewers_array = [friend_user_id_string2]
          @d.friend_likers_array = [friend_user_id_string3]
          @d.friend_rollers_array = [friend_user_id_string4]
          @d.friend_complete_viewers_array = [friend_user_id_string5]
          @d.save

          get '/v1/dashboard'

          response.body.should have_json_path("result/0/friend_sharers")
          response.body.should have_json_size(1).at_path("result/0/friend_sharers")
          response.body.should include_json("\"#{friend_user_id_string1}\"").at_path("result/0/friend_sharers")

          response.body.should have_json_path("result/0/friend_viewers")
          response.body.should have_json_size(1).at_path("result/0/friend_viewers")
          response.body.should include_json("\"#{friend_user_id_string2}\"").at_path("result/0/friend_viewers")

          response.body.should have_json_path("result/0/friend_likers")
          response.body.should have_json_size(1).at_path("result/0/friend_likers")
          response.body.should include_json("\"#{friend_user_id_string3}\"").at_path("result/0/friend_likers")

          response.body.should have_json_path("result/0/friend_rollers")
          response.body.should have_json_size(1).at_path("result/0/friend_rollers")
          response.body.should include_json("\"#{friend_user_id_string4}\"").at_path("result/0/friend_rollers")

          response.body.should have_json_path("result/0/friend_complete_viewers")
          response.body.should have_json_size(1).at_path("result/0/friend_complete_viewers")
          response.body.should include_json("\"#{friend_user_id_string5}\"").at_path("result/0/friend_complete_viewers")

          parse_json(response.body)["result"][0]["action"].should eq(DashboardEntry::ENTRY_TYPE[:entertainment_graph_recommendation])
        end

        it "should not return the friend arrays when the entry is not an entertainment graph recommendation" do
          get '/v1/dashboard'
          response.body.should have_json_path("result/0")
          response.body.should_not have_json_path("result/0/friend_sharers")
          response.body.should_not have_json_path("result/0/friend_viewers")
          response.body.should_not have_json_path("result/0/friend_likers")
          response.body.should_not have_json_path("result/0/friend_rollers")
          response.body.should_not have_json_path("result/0/friend_complete_viewers")
        end

      end

      it "should return 200 if no entries exist" do
        get '/v1/dashboard'
        response.status.should eq(200)
      end

      context 'short_link' do
        it "should return short_link for a dashboard_enrty on success" do
          d = Factory.build(:dashboard_entry)
          d.save
          short_link = "http://shl.by/1"
          GT::LinkShortener.stub(:get_or_create_shortlinks).and_return({'email'=>short_link})
          get '/v1/dashboard/'+d.id+'/short_link'
          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result/short_link")
          parse_json(response.body)["result"]["short_link"].should eq(short_link)
        end
      end

      context 'trigger_recs param' do
        it "should do a check for inserting recommendations when trigger_recs param is included" do
          GT::RecommendationManager.should_receive(:if_no_recent_recs_generate_rec).with(@u1, {:insert_at_random_location => true, :include_mortar_recs => false})
          get '/v1/dashboard?trigger_recs=true'
        end

        it "should do a check for inserting recommendations when trigger_recs param is included and recs_version param is 1" do
          GT::RecommendationManager.should_receive(:if_no_recent_recs_generate_rec).with(@u1, {:insert_at_random_location => true, :include_mortar_recs => false})
          get '/v1/dashboard?trigger_recs=true&recs_version=1'
        end

        it "also includes mortar recommendations when trigger_recs param is included and recs_version param is greater than 1" do
          GT::RecommendationManager.should_receive(:if_no_recent_recs_generate_rec).with(@u1, {:insert_at_random_location => true})
          get '/v1/dashboard?trigger_recs=true&recs_version=2'
        end

        it "creates a new dashboard from a video graph recommendation" do
          v = Factory.create(:video)
          rec_vid = Factory.create(:video)
          rec = Factory.create(:recommendation, :recommended_video_id => rec_vid.id, :score => 100.0)
          v.recs << rec
          v.save

          sharer = Factory.create(:user)
          f = Factory.create(:frame, :video => v, :creator => sharer )

          dbe = Factory.create(:dashboard_entry, :frame => f, :user => @u1, :video_id => v.id, :action => DashboardEntry::ENTRY_TYPE[:new_social_frame], :actor => sharer)
          dbe.save

          GT::VideoProviderApi.stub(:get_video_info)

          MongoMapper::Plugins::IdentityMap.clear

          lambda {
              get '/v1/dashboard?trigger_recs=true'
          }.should change { DashboardEntry.count }
        end

        context "mortar recommendation available" do

          before(:each) do
            @recommended_video = Factory.create(:video)
            @reason_video = Factory.create(:video)

            @mortar_recommendations = [
              {"item_id" => @recommended_video.id.to_s, "reason_id" => @reason_video.id.to_s},
            ]
            @mortar_recommendations.stub(:shuffle!)
            GT::MortarHarvester.stub(:get_recs_for_user).and_return(@mortar_recommendations)

            MongoMapper::Plugins::IdentityMap.clear

            Random.stub(:rand).and_return(Settings::Recommendations.triggered_ios_recs[:mortar_recs_weight] - 0.01)
          end

          it "creates a new dashboard entry from a mortar recommendation" do
            expect {
                get '/v1/dashboard?trigger_recs=true&recs_version=2'
            }.to change(DashboardEntry, :count)
          end

          it "does not create a new dashboard entry from a mortar recommendation when recs_version < 2" do
            expect {
                get '/v1/dashboard?trigger_recs=true'
            }.not_to change(DashboardEntry, :count)
          end

        end

        it "should not do a check for inserting recommendations when a since_id is included" do
          GT::RecommendationManager.should_not_receive(:if_no_recent_recs_generate_rec)
          get '/v1/dashboard?trigger_recs=true&since_id=someid'
        end

        it "should not do a check for inserting recommendations when trigger_recs param is not included" do
          GT::RecommendationManager.should_not_receive(:if_no_recent_recs_generate_rec)
          get '/v1/dashboard'
        end
      end

    end

    describe "PUT" do
      before(:each) do
        @r = Factory.create(:roll, :creator_id => @u1.id)
        @d = Factory.build(:dashboard_entry)
        @d.user = @u1
        @d.roll = @r
        @d.save
      end
      it "should return dashboard entry on success" do
        put '/v1/dashboard/'+@d.id+'?read=true'

        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_path("result")
        parse_json(response.body)["result"]["read"].should eq(true)
      end

      it "should return error if entry update not a success" do
        put '/v1/dashboard/'+@d.id+'?read=donkeybutt'

        response.body.should be_json_eql(200).at_path("status")
        parse_json(response.body)["result"]["read"].should_not eq("donkeybutt")
      end

      it "should return 404 if entry cant be found" do
        put '/v1/dashboard/'+@d.id+'xxx?read=true'
        response.body.should be_json_eql(404).at_path("status")
      end

    end

  end

  context "not logged in" do

    describe "All other API Routes besides GET" do
      it "should return 401 Unauthorized" do
        get '/v1/dashboard'
        response.status.should eq(401)
      end
    end

    context "short_link" do
      it "should work without authorization" do
          d = Factory.build(:dashboard_entry)
          d.save
          short_link = "http://shl.by/1"
          GT::LinkShortener.stub(:get_or_create_shortlinks).and_return({'email'=>short_link})
          get '/v1/dashboard/'+d.id+'/short_link'
          response.body.should be_json_eql(200).at_path("status")
      end
    end

  end

end
