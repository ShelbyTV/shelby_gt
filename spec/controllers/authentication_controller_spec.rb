require 'spec_helper'

# We're not trying to test Devise here, so just set current_user as expected when they get signed in...
class AuthenticationsController
  alias_method :sign_in_orig, :sign_in
  alias_method :current_user_orig, :current_user
  def sign_in_2(resource_or_scope, resource=nil) @current_user = resource; end
  def current_user_2() @current_user; end
  alias_method :sign_in, :sign_in_2
  alias_method :current_user, :current_user_2
end

describe AuthenticationsController do
  
  # Undo the Devise override stuff above so following tests work correctly
  after(:all) do
    AuthenticationsController.send :alias_method, :sign_in, :sign_in_orig
    AuthenticationsController.send :alias_method, :current_user, :current_user_orig
  end
  
  context "gt_enabled, non-faux user, just signing in" do
    before(:each) do
      request.stub!(:env).and_return({"omniauth.auth" => {'provider'=>'twitter'}})
      @u = Factory.create(:user, :gt_enabled => true, :faux => User::FAUX_STATUS[:false])
      User.stub(:first).and_return(@u)
      
      GT::UserManager.should_receive :start_user_sign_in
    end
    
    it "should simply sign the user in" do
      get :create
      assigns(:current_user).should == @u
      cookies[:_shelby_gt_common].should_not == nil
      assigns(:opener_location).should == Settings::ShelbyAPI.web_root
    end
    
    it "should handle redirect via session on sign in" do
      session[:return_url] = (url = "http://danspinosa.tv")
      get :create
      assigns(:opener_location).should == url
    end
    
    it "should handle redirect via omniauth on sign in" do
      request.env['omniauth.origin'] = (url = "http://danspinosa.tv")
      get :create
      assigns(:opener_location).should == url
    end

  end
  
  context "Adding new authentication to current user" do

    it "should do the correct things when a user adds an auth"
    
  end
  
  context "New User signing up!" do
    before(:each) do
      request.stub!(:env).and_return({"omniauth.auth" => {'provider'=>'twitter'}})
      User.stub(:first).and_return(nil)
    end

    it "should reject without additional permissions" do
      get :create
      assigns(:opener_location).should == "#{Settings::ShelbyAPI.web_root}/?access=nos"
    end
    
    it "should accept when GtInterest found" do
      gt_interest = Factory.create(:gt_interest)
      cookies[:gt_access_token] = gt_interest.id.to_s
      
      u = Factory.create(:user)
      GT::UserManager.should_receive(:create_new_user_from_omniauth).and_return(u)
      
      get :create
      assigns(:current_user).should == u
      assigns(:current_user).gt_enabled.should == true
      cookies[:_shelby_gt_common].should_not == nil
      assigns(:opener_location).should == Settings::ShelbyAPI.web_root
    end
    
    it "should be able to redirect when GtInterest found" do
      gt_interest = Factory.create(:gt_interest)
      cookies[:gt_access_token] = gt_interest.id.to_s
      
      u = Factory.create(:user)
      GT::UserManager.should_receive(:create_new_user_from_omniauth).and_return(u)
      
      session[:return_url] = (url = "http://danspinosa.tv")
      get :create
      assigns(:opener_location).should == url
    end
    
    it "should accept when invited to a roll" do
      cookies[:gt_roll_invite] = "uid,emial,rollid"
      User.should_receive(:find).with("uid").and_return Factory.create(:user, :gt_enabled => true)
      Roll.should_receive(:find).with("rollid").and_return Factory.create(:roll)
      GT::InvitationManager.should_receive :private_roll_invite
      
      u = Factory.create(:user)
      GT::UserManager.should_receive(:create_new_user_from_omniauth).and_return(u)
      
      get :create
      assigns(:current_user).should == u
      assigns(:current_user).gt_enabled.should == true
      cookies[:_shelby_gt_common].should_not == nil
      assigns(:opener_location).should == Settings::ShelbyAPI.web_root
    end
    
    it "should be able to redirect when invited to a roll" do
      cookies[:gt_roll_invite] = "uid,emial,rollid"
      User.should_receive(:find).with("uid").and_return Factory.create(:user, :gt_enabled => true)
      Roll.should_receive(:find).with("rollid").and_return Factory.create(:roll)
      GT::InvitationManager.should_receive :private_roll_invite
      
      u = Factory.create(:user)
      GT::UserManager.should_receive(:create_new_user_from_omniauth).and_return(u)
      
      session[:return_url] = (url = "http://danspinosa.tv")
      get :create
      assigns(:opener_location).should == url
    end
    
  end

  context "Current user with two seperate accounts" do

    it "should do the correct things when a user merges two seperate accts"
    
  end

  context "faux user" do
    before(:each) do
      request.stub!(:env).and_return({"omniauth.auth" => 
        {
          'provider'=>'twitter', 
          'credentials'=>{'token'=>nil, 'secret'=>nil}
        }})
      @u = Factory.create(:user, :gt_enabled => false, :faux => User::FAUX_STATUS[:true])
      User.stub(:first).and_return(@u)
    end
    
    it "should reject without additional permissions" do
      get :create
      assigns(:current_user).should == nil
    end
    
    it "should accept and convert if gt_enabled" do
      @u.gt_enabled = true
      @u.save
      
      GT::UserManager.should_receive :convert_faux_user_to_real
      GT::UserManager.should_receive :start_user_sign_in
      
      get :create
      assigns(:current_user).should == @u
      assigns(:current_user).gt_enabled.should == true
      cookies[:_shelby_gt_common].should_not == nil
      assigns(:opener_location).should == Settings::ShelbyAPI.web_root
    end
    
    it "should accept and convert if GtInterest found" do
      gt_interest = Factory.create(:gt_interest)
      cookies[:gt_access_token] = gt_interest.id.to_s
      
      GT::UserManager.should_receive :convert_faux_user_to_real
      GT::UserManager.should_receive :start_user_sign_in
      
      get :create
      assigns(:current_user).should == @u
      cookies[:_shelby_gt_common].should_not == nil
      assigns(:opener_location).should == Settings::ShelbyAPI.web_root
    end
    
    it "should be able to redirect on GtInterest" do
      gt_interest = Factory.create(:gt_interest)
      cookies[:gt_access_token] = gt_interest.id.to_s
      
      GT::UserManager.should_receive :convert_faux_user_to_real
      GT::UserManager.should_receive :start_user_sign_in
      
      session[:return_url] = (url = "http://danspinosa.tv")
      get :create
      assigns(:opener_location).should == url
    end
    
    it "should accept and convert if invited to a roll" do
      cookies[:gt_roll_invite] = :fake_invite
      GT::InvitationManager.should_receive :private_roll_invite
      
      GT::UserManager.should_receive :convert_faux_user_to_real
      GT::UserManager.should_receive :start_user_sign_in
      
      get :create
      assigns(:current_user).reload.should == @u
      cookies[:_shelby_gt_common].should_not == nil
      assigns(:opener_location).should == Settings::ShelbyAPI.web_root
    end
    
    it "should be able to redirect on roll invite" do
      cookies[:gt_roll_invite] = :fake_invite
      GT::InvitationManager.should_receive :private_roll_invite
      
      GT::UserManager.should_receive :convert_faux_user_to_real
      GT::UserManager.should_receive :start_user_sign_in
      
      session[:return_url] = (url = "http://danspinosa.tv")
      get :create
      assigns(:opener_location).should == url
    end
  end

  context "Create" do
    before(:each) do
      request.stub!(:env).and_return({"omniauth.auth" => {}})
      @u1 = Factory.create(:user, :gt_enabled => false)
      User.stub(:first).and_return(@u1)
    end

    it "should remove previous auth failure params from the query string for redirect" do
      controller.stub!(:session).and_return({:return_url => 'http://www.example.com?auth_failure=1&auth_strategy=Facebook&param1=val1&param2=val2'})  
      get :create, :provider => "Twitter"
      assigns(:opener_location).should eq('http://www.example.com?param1=val1&param2=val2')
    end

    it "should have no ? if the query string is empty after removing the auth failure params" do
      controller.stub!(:session).and_return({:return_url => 'http://www.example.com?auth_failure=1&auth_strategy=Facebook'})  
      get :create, :provider => "Twitter"
      assigns(:opener_location).should eq('http://www.example.com')
    end
  end

  context "Auth failure" do

    it "should add failure param to root url on auth failure" do
      get :fail
      assigns(:opener_location).should eq(Settings::ShelbyAPI.web_root + '?auth_failure=1')
    end

    it "should add failure param and strategy param to root url on auth failure when strategy specified" do
      get :fail, :strategy => 'Facebook'
      assigns(:opener_location).should eq(Settings::ShelbyAPI.web_root + '?auth_failure=1&auth_strategy=Facebook')
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

