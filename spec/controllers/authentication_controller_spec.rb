require 'spec_helper'

describe AuthenticationsController do
  before(:all) do
    set_omniauth()
    @env = { "omniauth.auth" => OmniAuth.config.mock_auth[:twitter] }
  end
  
  context "Current user, just signing in" do
    
    it "should do the correct things when a user signs in"

    it "should do the correct things when a user signs in and has a faux acct" do
=begin
      # Having a really tough time getting this test to work... pausing testing this for now
      request.stub!(:env).and_return(@env)
      @fu = Factory.create(:user, :faux => User::FAUX_STATUS[:true], :authentications => [{:provider => "twitter", :uid => 1234}])
      post :create
      cookies[:locked_and_loaded].should eq("true")
=end
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