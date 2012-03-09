require 'spec_helper'

describe V1::DashboardEntriesController do  
  describe "GET index" do
    it "should return the dashboard entrys to @dashboard and return 200" do
      @user = Factory.create(:user)
      sign_in @user
      
      roll = stub_model(Roll)
      frame = stub_model(Frame)
      video = stub_model(Video)
      conversation = stub_model(Conversation)
      
      dashboard_entry = { "roll" => roll,
                          "frame" => frame,
                          "video" => video,
                          "conversation" => conversation,
                          "user" => @user
                        }

      DashboardEntry.stub_chain(:limit, :skip, :where, :all).and_return([dashboard_entry])
      dashboard_entry.stub(:roll).and_return(roll)
      dashboard_entry.stub(:frame).and_return(frame)
      dashboard_entry.stub(:video).and_return(video)
      dashboard_entry.stub(:conversation).and_return(conversation)
      dashboard_entry.stub(:user).and_return(@user)
      
      get :index, :format => :json
      assigns(:entries).should eq([dashboard_entry])
      assigns(:status).should eq(200)
    end
    
    it "should return error if no entries found" do
      @user = Factory.create(:user)
      sign_in @user
      DashboardEntry.stub_chain(:limit, :skip, :where, :all).and_return([])
      get :index, :format => :json
      assigns(:status).should eq(500)
      assigns(:message).should eq("error retrieving dashboard entries")
    end
    
    it "should return error if could not find dashboard entry" do
      @user = Factory.create(:user)
      sign_in @user
      DashboardEntry.stub_chain(:limit, :skip, :where, :all).and_return([])
      get :index, :user_id => @user.id, :format => :json
      assigns(:status).should eq(500)   
    end
    
    it "should return error if could not find any user" do
      get :index, :format => :json
      assigns(:status).should eq(500)
      assigns(:message).should eq("no user info found, try again")
    end
    
  end
  
  describe "PUT update" do
    before(:each) do
      @d = mock_model(DashboardEntry, :update_attributes => true)
    end
    
    it "should return the dashboard entry to @dashboard and return 200" do
      DashboardEntry.stub(:find) { @d }
      @d.should_receive(:update_attributes).and_return(@d)
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
    
    it "should return error if could not updat dashboard entry" do
      DashboardEntry.stub(:find) { @d }
      @d.should_receive(:update_attributes).and_return(false)
      put :update, :id => @d.id, :format => :json
      assigns(:status).should eq(500)
      assigns(:message).should eq("could not update dashboard_entry")
    end
  end
  
end
