require 'spec_helper'

describe V1::DashboardEntriesController do  
  describe "GET index" do
    it "should return the dashboard entrys to @entries and return 200 when NOT including children" do
      @user = Factory.create(:user)
      sign_in @user
      
      video = mock_model(Video)
      frame = mock_model(Frame, :video_id => video.id)
      entry = mock_model(DashboardEntry, :frame => frame)
      
      DashboardEntry.stub_chain(:limit, :skip, :sort, :where, :all).and_return([entry])
      get :index, :include_children => "false", :format => :json
      assigns(:entries).should eq([entry])
      assigns(:status).should eq(200)
    end

    it "should return the dashboard entrys to @entries and return 200 when including children" do
      @user = Factory.create(:user)
      sign_in @user
      
      video = mock_model(Video)
      message = mock_model(Message)
      conv = mock_model(Conversation, :messages => [message])
      roll = mock_model(Roll)
      frame = mock_model(Frame, :video => video, :conversation => conv, :roll => roll)
      user = mock_model(User)
      entry = mock_model(DashboardEntry, :frame => frame, :roll => roll, :user => user, :video => video)
      
      DashboardEntry.stub_chain(:limit, :skip, :sort, :where, :all).and_return([entry])
      get :index, :include_children => "true", :format => :json
      assigns(:entries).should eq([entry])
      assigns(:status).should eq(200)
    end

    
    it "should return error if no entries found" do
      @user = Factory.create(:user)
      sign_in @user
      DashboardEntry.stub_chain(:limit, :skip, :sort, :where, :all).and_return([])
      get :index, :format => :json
      assigns(:status).should eq(204)
      assigns(:message).should eq("there are no dashboard entries for this user")
    end
    
    it "should return error if could not find dashboard entry" do
      @user = Factory.create(:user)
      sign_in @user
      DashboardEntry.stub_chain(:limit, :skip, :sort, :where, :all).and_return([])
      get :index, :user_id => @user.id, :format => :json
      assigns(:status).should eq(204)   
    end
    
    it "should return error if could not find any user" do
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
      assigns(:status).should eq(500)
      assigns(:message).should eq("could not find that dashboard_entry")
    end
    
    it "should return error if could not update dashboard entry" do
      DashboardEntry.stub(:find) { @d }
      @d.should_receive(:update_attributes!).and_raise(ArgumentError)
      put :update, :id => @d.id, :format => :json
      assigns(:status).should eq(500)
      assigns(:message).should eq("could not update dashboard_entry: ArgumentError")
    end
  end
  
end
