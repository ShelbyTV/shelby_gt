require 'spec_helper'

describe V1::UserController do

  before(:each) do
    @u1 = Factory.create(:user)
    User.stub(:find) { @u1 }
    r1 = Factory.create(:roll, :creator => @u1, :roll_type => Roll::TYPES[:special_public_real_user])
    r1.add_follower(@u1)
    r1.add_follower(Factory.create(:user))
    r2 = Factory.create(:roll, :creator => @u1, :roll_type => Roll::TYPES[:special_upvoted])
    r2.add_follower(@u1)
    @u1.public_roll = r1
    @u1.watch_later_roll = r2
    @u1.save
  end

  describe "POST create" do
    it "assigns new user to @user for JSON" do
      post :create, :format => :json, :user => { :name => "some name",
                                                 :nickname => Factory.next(:nickname),
                                                 :primary_email => Factory.next(:primary_email),
                                                 :password => "pass" }
      assigns(:status).should eq(200)
      assigns(:user).name.should == "some name"
      assigns(:user).authentication_token.should_not be_nil
      response.content_type.should == "application/json"
    end

    it "assigns new user to @user and redirects for HTML" do
      post :create, :format => :html, :user => { :name => "some name",
                                                 :nickname => Factory.next(:nickname),
                                                 :primary_email => Factory.next(:primary_email),
                                                 :password => "pass" }
      assigns(:user).name.should == "some name"
      response.should be_redirect
      response.should redirect_to("/")
    end

    it "assigns errord user to @user for JSON" do
      post :create, :format => :json, :user => { :name => "some name",
                                                 :nickname => @u1.nickname,
                                                 :primary_email => @u1.primary_email,
                                                 :password => "pass" }
      assigns(:status).should eq(409)
      response.content_type.should == "application/json"
    end

    it "assigns errord user to @user and redirects for HTML" do
      post :create, :format => :html, :user => { :name => "some name",
                                                 :nickname => @u1.nickname,
                                                 :primary_email => Factory.next(:primary_email),
                                                 :password => "pass" }

      response.should be_redirect
      response.should redirect_to("/user/new")
    end

    it "handles params without user" do
      post :create, :format => :json
      assigns(:status).should eq(409)
      response.content_type.should == "application/json"
    end

    context "without username, password" do

      it "can generate temporary username and password for JSON" do
        post :create, :format => :json, :generate_temporary_nickname_and_password => "1",
                                        :user => { :name => "some name",
                                                   :primary_email => Factory.next(:primary_email) }
        assigns(:status).should eq(200)
        assigns(:user).nickname.should_not be_nil
        assigns(:user).name.should == "some name"
        assigns(:user).authentication_token.should_not be_nil
        response.content_type.should == "application/json"
      end

      it "can generate temporary username and password for HTML" do
        post :create, :format => :html, :generate_temporary_nickname_and_password => "1",
                                        :user => { :name => "some name",
                                                   :primary_email => Factory.next(:primary_email) }
        assigns(:user).nickname.should_not be_nil
        assigns(:user).name.should == "some name"
        response.should be_redirect
        response.should redirect_to("/")
      end

      it "updates with client info (for JSON)" do
        client_string = "iOS_iPhone"
        post :create, :format => :json, :generate_temporary_nickname_and_password => "1",
                                        :client_identifier => client_string,
                                        :user => { :name => "some name",
                                                   :primary_email => Factory.next(:primary_email) }
        assigns(:status).should eq(200)
        assigns(:user).app_progress.onboarding.should == client_string
        assigns(:user).cohorts.include?(client_string).should == true
        assigns(:user).authentication_token.should_not be_nil
        response.content_type.should == "application/json"
      end

    end

  end

  describe "POST create dashboard entry for user" do
    before(:each) do
      @f =  Factory.create(:frame, :video => Factory.create(:video))
      sign_in @u1
    end

    it "returns 404 in no frame is found" do
      post :add_dashboard_entry, :id => @u1.id, :frame_id => "test", :format => :json
      assigns(:status).should eq(404)
    end

    it "should return 200 if alls hunky dory" do
      post :add_dashboard_entry, :id => @u1.id, :frame_id => @f.id.to_s, :format => :json
      assigns(:status).should eq(200)
    end

    it "should create a dbe that has the frame as part of it" do
      post :add_dashboard_entry, :id => @u1.id, :frame_id => @f.id.to_s, :format => :json
      assigns(:dashboard_entry).frame_id.should == @f.id
    end

    it "should have the right type" do
      post :add_dashboard_entry, :id => @u1.id, :frame_id => @f.id.to_s, :format => :json
      assigns(:dashboard_entry).action.should == ::DashboardEntry::ENTRY_TYPE[:new_hashtag_frame]
    end
  end

  describe "GET index" do
    it "assigns one user to @user" do
      sign_in @u1

      get :index, :format => :json
      assigns(:user).should eq(@u1)
      assigns(:status).should eq(200)
    end
  end

  describe "GET show" do

    it "should return user if valid user_id provided" do
      get :show, :id => @u1.id.to_s, :format => :json
      assigns(:user).should eq(@u1)
      assigns(:status).should eq(200)
    end

    it "should return user if valid user nickname provided" do
      User.stub(:find) { nil }
      User.should_receive(:find_by_nickname).with(@u1.nickname).and_return(@u1)
      get :show, :id => @u1.nickname, :format => :json
      assigns(:user).should eq(@u1)
      assigns(:status).should eq(200)
    end

    it "should return 404 if user_id provided, can't be found" do
      get :show, :id => "certainly this id doesn't exist", :format => :json
      assigns(:user).should eq(@u1)
      assigns(:status).should eq(200)
    end

    it "should return 401 if trying to get current_user and not signed in" do
      get :show, :format => :json
      assigns(:user).should == nil
      assigns(:status).should eq(401)
    end
  end

  describe "GET stats" do

    it "should return 401 if user not authenticated" do
      get :stats, :id => @u1.id.to_s, :format => :json
      assigns(:status).should eq(401)
    end

  end

  describe "PUT update" do
    before(:each) do
      sign_in @u1
    end

    it "updates a users nickname successfuly" do
      put :update, :id => @u1.id, :user => {:nickname=>"nick"}, :format => :json
      assigns(:user).should eq(@u1)
      assigns(:status).should eq(200)
    end

    it "updates a users preferences successfuly" do
      @u1.preferences.email_updates = true; @u1.save
      put :update, :id => @u1.id, :preferences => {:email_updates=>false}, :format => :json
      assigns(:user).preferences.email_updates.should eq(false)
      assigns(:status).should eq(200)
    end
  end

  describe "PUT log_session" do
    it "updates a users session count if logged in" do
      sign_in @u1
      s0 = @u1.session_count
      put :log_session, :id => @u1.id.to_s, :format => :json
      assigns(:status).should eq(200)
      @u1.reload.session_count.should eq (s0+1)
    end

    it "returns 401 if a user is not logged in" do
      put :log_session, :id=> '1', :format => :json
      assigns(:status).should eq(401)
    end
  end

  describe "GET signed_in" do
    it "returns 200 if signed in" do
      sign_in @u1
      get :signed_in, :format => :json
      assigns(:status).should eq(200)
      assigns(:signed_in).should eq(true)
    end

    it "returns 200 if signed out" do
      #don't sign_in @u1
      get :signed_in, :format => :json
      assigns(:status).should eq(200)
      assigns(:signed_in).should eq(false)
    end
  end

  describe "GET valid_token" do
    before(:each) do
      @auth = Authentication.new
      @u1.stub(:first_provider).and_return @auth
    end

    it "returns 200 with token_valid => true when FB token is valid" do
      GT::UserFacebookManager.stub(:verify_auth).and_return(true)
      sign_in @u1
      get :valid_token, :id => @u1.id.to_s, :provider => "facebook", :format => :json
      assigns(:status).should == 200
      assigns(:token_valid).should == true
    end

    it "returns 200 with taken_valid => false when FB token is invalid" do
      GT::UserFacebookManager.stub(:verify_auth).and_return(false)
      sign_in @u1
      get :valid_token, :id => @u1.id.to_s, :provider => "facebook", :format => :json
      assigns(:status).should == 200
      assigns(:token_valid).should == false
    end
  end

  describe "POST apn_token" do
    it "returns 200 on success" do
      sign_in @u1
      post :add_apn_token, :id => @u1.id.to_s, :token => '123', :format => :json
      assigns(:status).should == 200
    end

    it "returns 401 if the user is not authenticated" do
      post :add_apn_token, :id => @u1.id.to_s, :token => '123', :format => :json
      assigns(:status).should == 401
    end

    it "returns 401 if trying to access a user other than herself" do
      sign_in @u1
      post :add_apn_token, :id => BSON::ObjectId.new, :token => '123', :format => :json
      assigns(:status).should == 401
    end

    it "returns 500 if no token parameter is specified" do
      sign_in @u1
      post :add_apn_token, :id => @u1.id.to_s, :format => :json
      assigns(:status).should == 500
    end
  end

  describe "DELETE apn_token" do
    it "returns 200 on success" do
      sign_in @u1
      post :delete_apn_token, :id => @u1.id.to_s, :token => '123', :format => :json
      assigns(:status).should == 200
    end

    it "returns 401 if the user is not authenticated" do
      post :delete_apn_token, :id => @u1.id.to_s, :token => '123', :format => :json
      assigns(:status).should == 401
    end

    it "returns 401 if trying to access a user other than herself" do
      sign_in @u1
      post :delete_apn_token, :id => BSON::ObjectId.new, :token => '123', :format => :json
      assigns(:status).should == 401
    end

    it "returns 500 if no token parameter is specified" do
      sign_in @u1
      post :delete_apn_token, :id => @u1.id.to_s, :format => :json
      assigns(:status).should == 500
    end
  end

end
