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

          parse_json(response.body)["result"][0]["src_frame"]["id"].should eq(src_frame.id.to_s)
          parse_json(response.body)["result"][0]["src_frame"]["creator"]["id"].should eq(creator.id.to_s)
          parse_json(response.body)["result"][0]["src_frame"]["creator"]["nickname"].should eq(creator.nickname)
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
