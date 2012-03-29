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
    
  end

end