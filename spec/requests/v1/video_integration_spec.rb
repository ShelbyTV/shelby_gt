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
      GT::VideoManager.stub(:get_or_create_videos_for_url).and_return(@v);
      get 'v1/video/find_or_create', {:provider_id=>"id4", :provider_name=>"youtube", :url=>"http://www.url.com"}
      response.body.should be_json_eql(200).at_path("status");
    end
  end

end
