require 'spec_helper'

describe V1::TwitterController do

  describe "POST /follow" do
    before(:each) do
      @user = Factory.create(:user)
      sign_in @user
    end
    
    it "errors if user doesn't have twitter auth" do
      @user.authentications = []
      @user.save
      post :follow, :twitter_user_name => "whatever", :format => :json
      response.should_not be_success
    end
    
    it "should succeed with all required params" do
      post :follow, :twitter_user_name => "whatever", :format => :json
      response.should be_success
    end
    
  end
  
end