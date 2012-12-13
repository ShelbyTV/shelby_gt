require 'spec_helper'
describe V1::RemoteControlController do
  describe "CREATE" do
    it "creates a remote control code and returns it" do
      post :create, :format => :json
      assigns(:status).should eq(200)
    end
  end
  
  describe "UPDATE" do
    it "should trigger a command and return success" do
      
    end
  end
end