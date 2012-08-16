require 'spec_helper'

describe V1::TokenController do
  before(:each) do
    @user = Factory.create(:user) #adds a twitter authentication
    @twt_auth = @user.authentications[0]
    
    #no need to hit the net here
    GT::UserManager.stub(:start_user_sign_in)
  end

  describe "POST token" do
    it "assigns a User to @user if credentials are okay" do
      post :create, :provider_name => "twitter", :uid => @twt_auth.uid, :token => @twt_auth.oauth_token, :secret => @twt_auth.oauth_secret, :format => :json
      assigns(:user).should eq(@user)
      assigns(:status).should eq(200)
    end
    
    it "returns a 404 if credentials aren't okay" do
      GT::UserTwitterManager.should_receive(:verify_auth).with(@twt_auth.oauth_token, "bad").and_return(false)
      
      post :create, :provider_name => "twitter", :uid => @twt_auth.uid, :token => @twt_auth.oauth_token, :secret => "bad", :format => :json
      assigns(:status).should eq(404)
    end
    
    it "returns 404 when missing required token" do
      post :create, :provider_name => "twitter", :uid => @twt_auth.uid, :format => :json
      assigns(:status).should eq(404)
    end
  end
  
  describe "DELETE token" do
    before(:each) do
      @user.authentication_token = "authtoken"
      @user.save
    end
    
    it "resets the token and assigns the User to @user if given token is found" do
      delete :destroy, :id => @user.authentication_token, :format => :json
      assigns(:user).should eq(@user)
      assigns(:status).should eq(200)
    end
    
    it "returns a 404 if the given token isn't found" do
      delete :destroy, :id => "not the id", :format => :json
      assigns(:user).should eq(nil)
      assigns(:status).should eq(404)
    end
    
  end
  
end