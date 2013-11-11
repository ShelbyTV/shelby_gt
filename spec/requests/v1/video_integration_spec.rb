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
      @u1.watch_later_roll = Factory.create(:roll, :creator => @u1)
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

    it "should return an array of video ids from the viewed roll" do
      f1 = Factory.create(:frame, :creator => @u1, :roll => @u1.watch_later_roll, :video => Factory.create(:video))
      f2 = Factory.create(:frame, :creator => @u1, :roll => @u1.watch_later_roll, :video => Factory.create(:video))
      f3 = Factory.create(:frame, :creator => @u1, :roll => @u1.watch_later_roll, :video => Factory.create(:video))

      get '/v1/video/queued'
      response.body.should be_json_eql(200).at_path("status")
      response.body.should have_json_size(3).at_path("result")
      ids = parse_json(response.body)["result"].map{|frame| frame["id"]}
      ids.should include(f1.video.id.to_s)
      ids.should include(f2.video.id.to_s)
      ids.should include(f3.video.id.to_s)
    end

    it "should only return unique video ids" do
      v = Factory.create(:video)
      f1 = Factory.create(:frame, :creator => @u1, :roll => @u1.watch_later_roll, :video => v)
      f2 = Factory.create(:frame, :creator => @u1, :roll => @u1.watch_later_roll, :video => v)

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
