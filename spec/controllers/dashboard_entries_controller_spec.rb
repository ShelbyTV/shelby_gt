require 'spec_helper'

describe V1::DashboardEntriesController do
  describe "test token authenticable" do
    before(:each) do
      @user = Factory.create(:user)
      @user.ensure_authentication_token!
    end
    
    it "should validate request when auth token is included" do
      video = mock_model(Video)
      frame = Factory.create(:frame, :video_id => video.id)
      entry = mock_model(DashboardEntry, :frame => frame)
      DashboardEntry.stub_chain(:limit, :skip, :sort, :where, :all).and_return([entry])
      #---
      
      @user.authentication_token.should_not == nil
      get :index, :auth_token => @user.authentication_token, :format => :json
      assigns(:status).should eq(200)
    end
    
  end
  
  describe "GET index" do
    before(:each) do
      @user = Factory.create(:user)
      sign_in @user
    end
    
    it "should return the dashboard entrys to @entries and return 200 when NOT including children" do
      video = mock_model(Video)
      frame = Factory.create(:frame, :video_id => video.id)
      entry = mock_model(DashboardEntry, :frame => frame)
      
      DashboardEntry.stub_chain(:limit, :skip, :sort, :where, :all).and_return([entry])
      get :index, :include_children => "false", :format => :json
      assigns(:entries).should eq([entry])
      assigns(:status).should eq(200)
    end

    it "should return the dashboard entrys to @entries and return 200 when including children" do
      video = mock_model(Video)
      message = mock_model(Message)
      conv = mock_model(Conversation, :messages => [message])
      roll = mock_model(Roll)
      frame = Factory.create(:frame, :video => video, :conversation => conv, :roll => roll, :creator => @user)
      entry = mock_model(DashboardEntry, :frame => frame, :roll => roll, :creator => @user, :video => video)
      
      DashboardEntry.stub_chain(:limit, :skip, :sort, :where, :all).and_return([entry])
      get :index, :include_children => "true", :format => :json
      assigns(:entries).should eq([entry])
      assigns(:status).should eq(200)
    end
    
    it "should not return more than 20 entries" do
      30.times do |n|
        Factory.create(:dashboard_entry, :frame=>Factory.create(:frame))
      end
      DashboardEntry.stub_chain(:skip, :sort, :where, :all).and_return(DashboardEntry.first)
      get :index, :limit => 30, :format => :json
      assigns(:limit).should eq(20)
      assigns(:status).should eq(200)
    end
    
    it "should return error if no entries found" do
      DashboardEntry.stub_chain(:limit, :skip, :sort, :where, :all).and_return([])
      get :index, :format => :json
      assigns(:status).should eq(200)
      assigns(:entries).should eq([])
    end
    
    it "should return error if could not find dashboard entry" do
      DashboardEntry.stub_chain(:limit, :skip, :sort, :where, :all).and_return([])
      get :index, :user_id => @user.id, :format => :json
      assigns(:status).should eq(200)   
    end
    
    it "should return error if could not find any user" do
      sign_out(@user)
      get :index, :format => :json
      response.status.should eq(401)
    end
    
  end
  
  describe "PUT update" do
    before(:each) do
      @u = Factory.create(:user)
      sign_in @u
      @d = mock_model(DashboardEntry, :update_attributes => true)
    end
    
    it "should return the dashboard entry to @dashboard and return 200" do
      DashboardEntry.stub(:find) { @d }
      @d.should_receive(:update_attributes!).and_return(@d)
      put :update, :id => @d.id, :format => :json
      assigns(:dashboard_entry).should eq(@d)
      assigns(:status).should eq(200)
    end
    
    it "should return error if could not find dashboard entry" do
      DashboardEntry.stub(:find) { nil }
      put :update, :id => @d.id, :format => :json
      assigns(:status).should eq(404)
      assigns(:message).should eq("could not find that dashboard_entry")
    end
    
    it "should return error if could not update dashboard entry" do
      DashboardEntry.stub(:find) { @d }
      @d.should_receive(:update_attributes!).and_raise(ArgumentError)
      put :update, :id => @d.id, :format => :json
      assigns(:status).should eq(404)
      assigns(:message).should eq("could not update dashboard_entry: ArgumentError")
    end
  end
  
end
