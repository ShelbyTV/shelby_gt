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

    it "should return video info on success" do
      get 'v1/video/find_or_create', {:provider_id=>"id3", :provider_name=>"youtube"}
      response.body.should be_json_eql(200).at_path("status");
    end

    it "should create video info on success" do
      GT::VideoManager.stub(:get_or_create_videos_for_url).and_return({:videos => [@v]});
      get 'v1/video/find_or_create', {:provider_id=>"id4", :provider_name=>"youtu", :url=>"http://www.url.com"}
      response.body.should be_json_eql(200).at_path("status");
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
      f1 = Factory.create(:frame, :creator => @u1, :roll => @u1.viewed_roll, :video => Factory.create(:video))
      f2 = Factory.create(:frame, :creator => @u1, :roll => @u1.viewed_roll, :video => Factory.create(:video))
      f3 = Factory.create(:frame, :creator => @u1, :roll => @u1.viewed_roll, :video => Factory.create(:video))
      
      get '/v1/video/viewed'
      response.body.should be_json_eql(200).at_path("status")
      response.body.should have_json_size(3).at_path("result")
      parse_json(response.body)["result"][0]["id"].should == f1.video.id.to_s
      parse_json(response.body)["result"][1]["id"].should == f2.video.id.to_s
      parse_json(response.body)["result"][2]["id"].should == f3.video.id.to_s
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
      parse_json(response.body)["result"][0]["id"].should == f1.video.id.to_s
      parse_json(response.body)["result"][1]["id"].should == f2.video.id.to_s
      parse_json(response.body)["result"][2]["id"].should == f3.video.id.to_s
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
  
  describe "POST unplayable" do
    before(:each) do
      @u1 = Factory.create(:user)
      
      #sign that user in
      set_omniauth(:uuid => @u1.authentications.first.uid)
      get '/auth/twitter/callback'
    end
    
    it "should return video info on success" do
      post '/v1/video/'+@v.id+'/unplayable'
      response.body.should be_json_eql(200).at_path("status")
      response.body.should have_json_path("result/title")
      response.body.should have_json_path("result/first_unplayable_at")
      response.body.should have_json_path("result/last_unplayable_at")
    end
    
    it "should return 404 when video not found" do
      post '/v1/video/'+@v.id+'33/unplayable'
      response.body.should be_json_eql(404).at_path("status")
    end
  end

end
