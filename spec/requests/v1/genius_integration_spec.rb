require 'spec_helper' 

describe 'v1/roll' do
  before(:all) do
    @u1 = Factory.create(:user)
  end
  
  context 'logged in' do
    before(:all) do
      set_omniauth(:uuid => @u1.authentications.first.uid)
      get '/auth/twitter/callback'
    end
    
    describe "POST" do
      context "genius roll creation" do
        it "should create and return a genius roll on success" do
          GT::UrlHelper.stub( "parse_url_for_provider_info").and_return({:provider_name => "name", :provider_id=>"id"})
          post '/v1/roll/genius?search=Beyonce&urls=%5B%22http%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3D4m1EFMoRFvY%26feature%3Dyoutube_gdata%22%2C%22http%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3DdunGhkCmYKM%26feature%3Dyoutube_gdata%22%5D'

          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result/title")
          response.body.should have_json_path("result/genius")
          parse_json(response.body)["result"]["title"].should eq("GENIUS: Beyonce")
          parse_json(response.body)["result"]["genius"].should eq(true)
        end

        it "should return 404 if there are no urls" do
          post '/v1/roll/genius?search=Beyonce'      
          response.body.should be_json_eql(404).at_path("status")
        end

        it "should return 404 if there is no search or no urls" do
          post '/v1/roll/genius' 
          response.body.should be_json_eql(404).at_path("status")
        end        
      end
    end
  end
  
  context "not logged in" do
    describe "POST" do
      context "genius roll creation" do
        it "should create and return a genius roll on success" do
          GT::UrlHelper.stub(:parse_url_for_provider_info).and_return({:provider_name => "name", :provider_id => "id"})
          post '/v1/roll/genius?search=Beyonce&urls=%5B%22http%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3D4m1EFMoRFvY%26feature%3Dyoutube_gdata%22%2C%22http%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3DdunGhkCmYKM%26feature%3Dyoutube_gdata%22%5D'

          response.body.should be_json_eql(200).at_path("status")
          response.body.should have_json_path("result/title")
          response.body.should have_json_path("result/genius")
          parse_json(response.body)["result"]["title"].should eq("GENIUS: Beyonce")
          parse_json(response.body)["result"]["genius"].should eq(true)
        end

        it "should return 404 if there are no urls" do
          post '/v1/roll/genius?search=Beyonce'      
          response.body.should be_json_eql(404).at_path("status")
        end

        it "should return 404 if there is no search or no urls" do
          post '/v1/roll/genius' 
          response.body.should be_json_eql(404).at_path("status")
        end        
      end
    end
  end
end
