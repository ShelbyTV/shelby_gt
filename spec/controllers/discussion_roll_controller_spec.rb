require 'spec_helper'

describe V1::DiscussionRollController do
  describe "POST create" do
    before(:each) do
      @video = Factory.create(:video)
      @frame = Factory.create(:frame)
      
      @u1, @u2 = Factory.create(:user), Factory.create(:user)
      @u1.save
      sign_in @u1
    end
    
    it "should return 200 if given a frame" do
      post :create, :frame_id => @frame.id.to_s, :participants => "dan@shelby.tv", :message => "message", :format => :json
      assigns(:status).should eq(200)
    end
    
    it "should return 200 if given a video" do
      post :create, :video_id => @video.id.to_s, :participants => "dan@shelby.tv", :message => "message", :format => :json
      assigns(:status).should eq(200)
    end
    
    it "should return 200 if participants include real users" do
      post :create, :video_id => @video.id.to_s, :participants => "dan@shelby.tv,#{@u2.nickname}", :message => "message", :format => :json
      assigns(:status).should eq(200)
    end
  end
  
  describe "GET show" do
    before(:each) do
      @video = Factory.create(:video)
      @frame = Factory.create(:frame)
      
      @roll = Factory.create(:roll)
      
      @u1, @u2 = Factory.create(:user), Factory.create(:user)
      @u1.save
    end
    
    it "should return 200 if user is logged in" do
      sign_in @u1
      get :show, :id => @roll.id, :format => :json
      assigns(:status).should == 200
    end
    
    it "should return 200 if token is valid for non-shelby user" do
      token = GT::DiscussionRollUtils.encrypt_roll_user_identification(@roll, "dan@shelby.tv")
      get :show, :id => @roll.id, :token => CGI.escape(token), :format => :json
      assigns(:status).should == 200
    end
    
    it "should return 200 if token is valid for logged in user" do
      sign_in @u1
      token = GT::DiscussionRollUtils.encrypt_roll_user_identification(@roll, "dan@shelby.tv")
      get :show, :id => @roll.id, :token => CGI.escape(token), :format => :json
      assigns(:status).should == 200
    end
    
    it "should return 404 if token is invalid" do
      token = "bad token"
      get :show, :id => @roll.id, :token => CGI.escape(token), :format => :json
      assigns(:status).should == 404
    end
    
    it "should return 404 if roll DNE" do
      token = GT::DiscussionRollUtils.encrypt_roll_user_identification(@roll, "dan@shelby.tv")
      get :show, :id => Factory.create(:user).id, :token => CGI.escape(token), :format => :json
      assigns(:status).should == 404
    end
  end
  
  describe "POST message" do
    before(:each) do
      @video = Factory.create(:video)
      @frame = Factory.create(:frame)
      
      @roll = Factory.create(:roll)
      
      @u1, @u2 = Factory.create(:user), Factory.create(:user)
      @u1.save
      
      GT::Framer.re_roll(@frame, @u1, @roll, true)
    end
    
    it "should return 200 if user is logged in" do
      sign_in @u1
      post :create_message, :discussion_roll_id => @roll.id, :message => "msg", :format => :json
      assigns(:status).should == 200
    end
    
    it "should return 400 if message parameter is missing" do
      sign_in @u1
      post :create_message, :discussion_roll_id => @roll.id, :format => :json
      assigns(:status).should == 400
    end
    
    it "should return 200 if token is valid for non-shelby user" do
      token = GT::DiscussionRollUtils.encrypt_roll_user_identification(@roll, "dan@shelby.tv")
      post :create_message, :discussion_roll_id => @roll.id, :token => CGI.escape(token), :message => "msg", :format => :json
      assigns(:status).should == 200
    end
    
    it "should return 200 if token is valid for logged in user" do
      sign_in @u1
      token = GT::DiscussionRollUtils.encrypt_roll_user_identification(@roll, "dan@shelby.tv")
      post :create_message, :discussion_roll_id => @roll.id, :token => CGI.escape(token), :message => "msg", :format => :json
      assigns(:status).should == 200
    end
    
    it "should return 404 if token is invalid" do
      token = "bad token"
      post :create_message, :discussion_roll_id => @roll.id, :token => CGI.escape(token), :message => "msg", :format => :json
      assigns(:status).should == 404
    end
    
    it "should return 404 if roll DNE" do
      token = GT::DiscussionRollUtils.encrypt_roll_user_identification(@roll, "dan@shelby.tv")
      post :create_message, :discussion_roll_id => "badid", :token => CGI.escape(token), :message => "msg", :format => :json
      assigns(:status).should == 404
    end
  end
end