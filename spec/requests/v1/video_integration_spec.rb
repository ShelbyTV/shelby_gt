require 'spec_helper'

describe 'v1/video' do
  before(:each) do
    @v = Factory.create(:video, :title=>"test title")
  end

  describe "GET" do
    it "should return video info on success" do
      get '/v1/video/'+@v.id
      response.body.should be_json_eql(200).at_path("status")
      response.body.should have_json_path("result/title")
      response.body.should have_json_path("result/tracked_liker_count")

      parsed_response = parse_json(response.body)
      parsed_response["result"]["tracked_liker_count"].should == @v.tracked_liker_count
    end

    it "should return error message if video doesnt exist" do
      get '/v1/video/'+@v.id+'xxx'
      response.body.should be_json_eql(404).at_path("status")
    end

    context "find_or_create" do

      it "should return video info on success" do
        get 'v1/video/find_or_create', {:provider_id=>@v.provider_id, :provider_name=>"youtube"}
        response.body.should be_json_eql(200).at_path("status");
        response.body.should have_json_path("result/available")
        response.body.should have_json_path("result/like_count")
        response.body.should have_json_path("result/tracked_liker_count")

        parsed_response = parse_json(response.body)
        parsed_response["result"]["like_count"].should == @v.like_count
        parsed_response["result"]["tracked_liker_count"].should == @v.tracked_liker_count
      end

      it "should create video info on success when video is not in db and url param is passed" do
        GT::VideoManager.stub(:get_or_create_videos_for_url).and_return({:videos => [@v]});
        get 'v1/video/find_or_create', {:provider_id=>@v.provider_id, :provider_name=>"vimeo", :url=>"http://www.url.com"}
        assigns(:url).should == "http://www.url.com"
        response.body.should be_json_eql(200).at_path("status");
      end

      it "should create video info on success when video is not in db and url param IS NOT passed" do
        GT::VideoManager.stub(:get_or_create_videos_for_url).and_return({:videos => [@v]});
        get 'v1/video/find_or_create', {:provider_id=>@v.provider_id, :provider_name=>"dailymotion"}
        assigns(:url).should == "http://www.dailymotion.com/video/#{@v.provider_id}"
        response.body.should be_json_eql(200).at_path("status");
      end

    end
  end

  describe "GET likers" do
    it "returns status 200 and base level information on success" do
      get '/v1/video/'+@v.id+'/likers'
      response.body.should be_json_eql(200).at_path("status")
      response.body.should have_json_path("result/video")
      response.body.should have_json_path("result/video/id")
      response.body.should have_json_path("result/video/provider_name")
      response.body.should have_json_path("result/video/provider_id")
      response.body.should have_json_path("result/video/tracked_liker_count")
      response.body.should have_json_path("result/likers")
      response.body.should have_json_type(Array).at_path("result/likers")
      response.body.should have_json_size(0).at_path("result/likers")

      parsed_response = parse_json(response.body)
      parsed_response["result"]["video"]["id"].should == @v.id.to_s
      parsed_response["result"]["video"]["provider_name"].should == @v.provider_name
      parsed_response["result"]["video"]["provider_id"].should == @v.provider_id
      parsed_response["result"]["video"]["tracked_liker_count"].should == @v.tracked_liker_count
    end

    context "some likers available for the video" do

      before(:each) do
        Settings::VideoLiker["bucket_size"] = 3

        @likers = []
        buckets = []
        2.times do |i|
          buckets << Factory.create(:video_liker_bucket, :provider_name => @v.provider_name, :provider_id => @v.provider_id, :sequence => i)
          Settings::VideoLiker.bucket_size.times do
            public_roll = Factory.create(:roll)
            liker = Factory.create(:user, :public_roll => public_roll)
            @likers << liker
            buckets[i].likers << Factory.create(:video_liker, {
              :user_id => liker.id,
              :nickname => liker.nickname,
              :name => liker.name,
              :public_roll => liker.public_roll,
              :user_image => liker.user_image,
              :user_image_original => liker.user_image_original,
              :has_shelby_avatar => liker.has_shelby_avatar
            })
          end
          buckets[i].save
        end
        MongoMapper::Plugins::IdentityMap.clear
      end

      it "returns info on a full bucket of likers in order of recency by default" do

        get '/v1/video/'+@v.id+'/likers'

        response.body.should have_json_size(Settings::VideoLiker.bucket_size).at_path("result/likers")
        response.body.should have_json_path("result/likers/0/user")
        response.body.should have_json_path("result/likers/0/user/id")
        response.body.should have_json_path("result/likers/0/user/name")
        response.body.should have_json_path("result/likers/0/user/nickname")
        response.body.should have_json_path("result/likers/0/user/personal_roll_id")
        response.body.should have_json_path("result/likers/0/user/user_image")
        response.body.should have_json_path("result/likers/0/user/user_image_original")
        response.body.should have_json_path("result/likers/0/user/has_shelby_avatar")

        parsed_response = parse_json(response.body)
        parsed_response["result"]["likers"][0]["user"]["id"].should == @likers[-1].id.to_s
        parsed_response["result"]["likers"][0]["user"]["name"].should == @likers[-1].name
        parsed_response["result"]["likers"][0]["user"]["nickname"].should == @likers[-1].nickname
        parsed_response["result"]["likers"][0]["user"]["personal_roll_id"].should == @likers[-1].public_roll_id.to_s
        parsed_response["result"]["likers"][0]["user"]["user_image"].should == @likers[-1].user_image
        parsed_response["result"]["likers"][0]["user"]["user_image_original"].should == @likers[-1].user_image_original
        parsed_response["result"]["likers"][0]["user"]["has_shelby_avatar"].should == @likers[-1].has_shelby_avatar

        parsed_response["result"]["likers"][1]["user"]["id"].should == @likers[-2].id.to_s
        parsed_response["result"]["likers"][2]["user"]["id"].should == @likers[-3].id.to_s
      end

      it "respects the limit parameter when it's midway into a bucket" do
        get '/v1/video/'+@v.id+'/likers?limit=4'

        response.body.should have_json_size(4).at_path("result/likers")

        parsed_response = parse_json(response.body)
        parsed_response["result"]["likers"][0]["user"]["id"].should == @likers[-1].id.to_s
        parsed_response["result"]["likers"][1]["user"]["id"].should == @likers[-2].id.to_s
        parsed_response["result"]["likers"][2]["user"]["id"].should == @likers[-3].id.to_s
        parsed_response["result"]["likers"][3]["user"]["id"].should == @likers[-4].id.to_s
      end

       it "respects the limit parameter when it's greater than the number of likers that can be found" do
        get '/v1/video/'+@v.id+'/likers?limit=7'

        response.body.should have_json_size(6).at_path("result/likers")
      end
    end

    it "returns error message if video doesnt exist" do
      get '/v1/video/'+@v.id+'xxx/likers'
      response.body.should be_json_eql(404).at_path("status")
    end
  end

  describe "GET viewed" do
    before(:each) do
      @u1 = Factory.create(:user)
      @u1.viewed_roll = Factory.create(:roll, :creator => @u1)
      @u1.save

      #sign that user in
      set_omniauth(:uuid => @u1.authentications.first.uid)
      get '/auth/twitter/callback'
    end

    it "should return an empty array of video ids" do
      get '/v1/video/viewed'
      response.body.should be_json_eql(200).at_path("status")
      response.body.should have_json_size(0).at_path("result")
    end

    it "should return an array of video ids from the viewed roll" do
      f1 = Factory.create(:frame, :creator => @u1, :roll => @u1.viewed_roll, :video => (v1 = Factory.create(:video)))
      f2 = Factory.create(:frame, :creator => @u1, :roll => @u1.viewed_roll, :video => (v2 = Factory.create(:video)))
      f3 = Factory.create(:frame, :creator => @u1, :roll => @u1.viewed_roll, :video => (v3 = Factory.create(:video)))

      get '/v1/video/viewed'
      response.body.should be_json_eql(200).at_path("status")
      response.body.should have_json_size(3).at_path("result")

      viewed_video_ids = parse_json(response.body)["result"].map {|vid| vid["id"]}
      expect(viewed_video_ids).to include(v1.id.to_s)
      expect(viewed_video_ids).to include(v2.id.to_s)
      expect(viewed_video_ids).to include(v3.id.to_s)
    end

    it "should only return unique video ids" do
      v = Factory.create(:video)
      f1 = Factory.create(:frame, :creator => @u1, :roll => @u1.viewed_roll, :video => v)
      f2 = Factory.create(:frame, :creator => @u1, :roll => @u1.viewed_roll, :video => v)

      get '/v1/video/viewed'
      response.body.should be_json_eql(200).at_path("status")
      response.body.should have_json_size(1).at_path("result")
      parse_json(response.body)["result"][0]["id"].should == f1.video.id.to_s
    end
  end

  describe "GET queued" do
    before(:each) do
      @u1 = Factory.create(:user)
      @u1.public_roll = Factory.create(:roll, :creator => @u1)
      @u1.save

      #sign that user in
      set_omniauth(:uuid => @u1.authentications.first.uid)
      get '/auth/twitter/callback'
    end

    it "should return an empty array of video ids" do
      get '/v1/video/queued'
      response.body.should be_json_eql(200).at_path("status")
      response.body.should have_json_size(0).at_path("result")
    end

    it "should return an array of video ids from the user's public roll that are light weight shares" do
      f1 = Factory.create(:frame, :creator => @u1, :roll => @u1.public_roll, :video => Factory.create(:video), :frame_type => Frame::FRAME_TYPE[:light_weight])
      f2 = Factory.create(:frame, :creator => @u1, :roll => @u1.public_roll, :video => Factory.create(:video), :frame_type => Frame::FRAME_TYPE[:light_weight])
      f3 = Factory.create(:frame, :creator => @u1, :roll => @u1.public_roll, :video => Factory.create(:video))

      get '/v1/video/queued'
      response.body.should be_json_eql(200).at_path("status")
      response.body.should have_json_size(2).at_path("result")
      ids = parse_json(response.body)["result"].map{|frame| frame["id"]}
      ids.should include(f1.video.id.to_s)
      ids.should include(f2.video.id.to_s)
      ids.should_not include(f3.video.id.to_s)
    end

    it "should only return unique video ids" do
      v = Factory.create(:video)
      f1 = Factory.create(:frame, :creator => @u1, :roll => @u1.public_roll, :video => v, :frame_type => Frame::FRAME_TYPE[:light_weight])
      f2 = Factory.create(:frame, :creator => @u1, :roll => @u1.public_roll, :video => v, :frame_type => Frame::FRAME_TYPE[:light_weight])

      get '/v1/video/queued'
      response.body.should be_json_eql(200).at_path("status")
      response.body.should have_json_size(1).at_path("result")
      parse_json(response.body)["result"][0]["id"].should == f1.video.id.to_s
    end
  end

  describe "GET search" do
    it "should return 404 if provider or query not given" do
      get '/v1/video/search'
      response.body.should be_json_eql(404).at_path("status")

      get '/v1/video/search?provider=vimeo'
      response.body.should be_json_eql(404).at_path("status")

      get '/v1/video/search?query=blah'
      response.body.should be_json_eql(404).at_path("status")
    end

    it "should not accept an invalid provider" do
      get '/v1/video/search?provider=blah&q=test'
      response.body.should be_json_eql(404).at_path("status")
    end

    it "should return 200 if alls well that ends well" do
      get '/v1/video/search?provider=vimeo&q=test'
      response.body.should be_json_eql(200).at_path("status")
    end

  end

  describe "PUT watched" do

    context "logged in" do
      before(:each) do
        @u1 = Factory.create(:user)

        #sign that user in
        set_omniauth(:uuid => @u1.authentications.first.uid)
        get '/auth/twitter/callback'
      end

      it "should return video info on success" do
        put '/v1/video/'+@v.id+'/watched'
        response.body.should be_json_eql(200).at_path("status")
        response.body.should be_json_eql(1).at_path("result/view_count")
      end

      it "should add to the user's viewed roll" do
        lambda {
          put '/v1/video/'+@v.id+'/watched'
        }.should change { Frame.count }
      end

      it "should return 404 when video not found" do
        put '/v1/video/badid/watched'
        response.body.should be_json_eql(404).at_path("status")
      end
    end

    context "logged out" do
      it "should return video info on success" do
        put '/v1/video/'+@v.id+'/watched'
        response.body.should be_json_eql(200).at_path("status")
        response.body.should be_json_eql(1).at_path("result/view_count")
      end

      it "should not add to any roll" do
        lambda {
          put '/v1/video/'+@v.id+'/watched'
        }.should_not change { Frame.count }
      end
    end

  end

  describe "PUT unplayable" do
    before(:each) do
      @u1 = Factory.create(:user)

      #sign that user in
      set_omniauth(:uuid => @u1.authentications.first.uid)
      get '/auth/twitter/callback'
    end

    it "should return video info on success" do
      put '/v1/video/'+@v.id+'/unplayable'
      response.body.should be_json_eql(200).at_path("status")
      response.body.should have_json_path("result/title")
      response.body.should have_json_path("result/first_unplayable_at")
      response.body.should have_json_path("result/last_unplayable_at")
    end

    it "should return 404 when video not found" do
      put '/v1/video/'+@v.id+'33/unplayable'
      response.body.should be_json_eql(404).at_path("status")
    end
  end

end
