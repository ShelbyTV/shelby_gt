require 'spec_helper'

describe V1::Roll::GeniusController do
  before(:each) do
    @u1 = Factory.create(:user)
    sign_in @u1
    @roll = Factory.create(:roll, :creator => nil)
  end
  
  describe "POST create" do
    before(:each) do
      @roll = Factory.create(:roll, :creator_id => nil)
    end
    
    it "creates and assigns one genius roll to @roll if user signed in"
    
    it "creates and assigns one genius roll to @roll if user signed out"

    it "returns 404 if search parameter not provided" do
      post :create, :urls => "%5B%22http%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3D4m1EFMoRFvY%26feature%3Dyoutube_gdata%22%2C%22http%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3DdunGhkCmYKM%26feature%3Dyoutube_gdata%22%5D", :format => :json
      assigns(:status).should eq(404)
    end
    
    it "returns 404 if urls parameter not provided" do
      post :create, :search => "Beyonce", :format => :json
      assigns(:status).should eq(404)
    end
    
    it "returns 404 if urls parameter does not contain JSON array" do
      post :create, :search => "Beyonce", :urls => "", :format => :json
      assigns(:status).should eq(404)
    end
 
    it "returns 404 if urls parameter contain invalid JSON array" do
      post :create, :search => "Beyonce", :urls => "%5B%5D", :format => :json
      assigns(:status).should eq(404)
    end
    
    it "returns 404 if no parameters set" do
      post :create, :format => :json
      assigns(:status).should eq(404)
    end
    
  end
end  
