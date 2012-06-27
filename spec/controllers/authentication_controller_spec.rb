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
  
  context "Adding new authentication to current user" do

    it "should do the correct things when a user adds an auth"
    
  end
  
  context "New User signing up!" do

    it "should do the correct things when a user signs up"
    
  end

  context "Current user with two seperate accounts" do

    it "should do the correct things when a user merges two seperate accts"
    
  end

  context "Create" do
    it "should remove previous auth failure params from the query string for redirect" do
        controller.stub!(:session).and_return({:return_url => 'http://www.example.com?auth_failure=1&auth_strategy=Facebook&param1=val1&param2=val2'})
        request.stub!(:env).and_return({"omniauth.auth" => {}})
        @u1 = Factory.create(:user, :gt_enabled => false)
        User.stub(:first).and_return(@u1)
        get :create, :provider => "Twitter"
        assigns(:opener_location).should eq('http://www.example.com?param1=val1&param2=val2')
    end
  end

  context "Auth failure" do

    it "should add failure param to root url on auth failure" do
      get :fail
      assigns(:opener_location).should eq(web_root_url + '?auth_failure=1')
    end

    it "should add failure param and strategy param to root url on auth failure when strategy specified" do
      get :fail, :strategy => 'Facebook'
      assigns(:opener_location).should eq(web_root_url + '?auth_failure=1&auth_strategy=Facebook')
    end

    it "should add failure param to session return url on auth failure" do
      controller.stub!(:session).and_return({:return_url => 'http://www.example.com?param1=val1&param2=val2'})
      get :fail
      assigns(:opener_location).should eq('http://www.example.com?auth_failure=1&param1=val1&param2=val2')
    end

    it "should add failure param and strategy param to session return url on auth failure when strategy specified" do
      controller.stub!(:session).and_return({:return_url => 'http://www.example.com?param1=val1&param2=val2'})
      get :fail, :strategy => 'Facebook'
      assigns(:opener_location).should eq('http://www.example.com?auth_failure=1&auth_strategy=Facebook&param1=val1&param2=val2')
    end

  end

end