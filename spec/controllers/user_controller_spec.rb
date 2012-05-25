require 'spec_helper'

describe V1::UserController do
  
  before(:each) do
    @u1 = Factory.create(:user)
    User.stub(:find) { @u1 }
    r1 = Factory.create(:roll, :creator => @u1)
    r1.add_follower(@u1)
    r2 = Factory.create(:roll, :creator => @u1)
    r2.add_follower(@u1)
    @u1.public_roll = r1
    @u1.upvoted_roll = r2
    @u1.save
    
    sign_in @u1
  end
    
  describe "GET show" do
    it "assigns one user to @user" do
      get :show, :format => :json
      assigns(:user).should eq(@u1)
      assigns(:status).should eq(200)
    end
  end

  describe "GET rolls" do
    it "returns rolls followed of the authed in user" do
      get :roll_followings, :id => @u1.id, :format => :json
      assigns(:status).should eq(200)
    end
    
    it "returns 403 if the user is not the authed in user" do
      u2 = Factory.create(:user, :nickname => "name")
      get :roll_followings, :id => u2.id, :format => :json
      assigns(:status).should eq(403)
    end
  end
  
  describe "PUT update" do
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

  describe "GET signed_in" do
    it "returns 200 if signed in" do
      get :signed_in, :format => :json
      assigns(:status).should eq(200)
      assigns(:signed_in).should eq(true)
    end

    it "returns 200 if signed out" do
      sign_out(@u1)
      get :signed_in, :format => :json
      assigns(:status).should eq(200)
      assigns(:signed_in).should eq(false)
    end


  end
end