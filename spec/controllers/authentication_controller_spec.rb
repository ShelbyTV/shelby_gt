require 'spec_helper'

describe AuthenticationsController do
  before(:all) do

  end
  
  context "Current user, just signing in" do
    
    it "should do the correct things when a user signs in"
=begin
      u = Factory.create(:user)
      a = u.authentications.first
      
      auth = { "provider" => a.provider, "uid" => a.uid, "credentials" => {"token" => "token", "secret" => "secret"} }
      setup_omniauth_env(auth)
      
      get :create
      should be_user_signed_in
    end
=end

    it "should do the correct things when a user signs in and has a faux acct"
=begin
      # Having a really tough time getting this test to work... pausing testing this for now
      request.stub!(:env).and_return(@env)
      @fu = Factory.create(:user, :faux => User::FAUX_STATUS[:true], :authentications => [{:provider => "twitter", :uid => 1234}])
      post :create
      cookies[:signed_in].should eq("true")
    end
=end
    
  end
  
  context "current user, signing out" do
    before(:each) do
      @u = Factory.create(:user)
      sign_in @u
    end
    
    it "should remove the signed_in cookie" do
      cookies.should_receive(:delete).with("remember_user_token", {}) #from omniauth
      cookies.should_receive(:delete).with(:signed_in, :domain => '.shelby.tv') #from auth
      
      get :sign_out_user, :format => :json
    end
  end

  context "Adding new authentication to current user" do

    it "should do the correct things when a user adds an auth"
    
  end
  
  context "New User signing up!" do

    it "should do the correct things when a user signs up"
    
  end

  context "Current user with two seperate accounts" do

    it "should do the correct things when a user merges two seperate accts"
    
  end

end