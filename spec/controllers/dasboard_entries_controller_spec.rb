require 'spec_helper'

describe V1::DashboardEntriesController do
  before(:each) do
    @user = stub_model(User)
    @d1 = stub_model(Frame)
    @d2 = stub_model(Frame)
    
    User.stub(:find) { @user }
    DashboardEntry.stub(:where) { [@d1, @d2] }
  end
  
  describe "GET index" do
    it "should return the dashboard entrys to @dashboard and return 200" do
      get :index, :user_id => @user.id, :format => :json
      assigns(:status).should eq(200)
    end
    
    it "should return error if could not find dashboard entry" do
      DashboardEntry.stub_chain(:limit, :skip, :where).and_return([])
      get :index, :user_id => @user.id, :format => :json
      assigns(:status).should eq(500)   
    end
    
    it "should return error if could not find a user" do
      get :index, :format => :json
      assigns(:status).should eq(500)
    end
    
  end
  
  describe "PUT update" do
    it "should return the dashboard entry to @dashboard and return 200" do
      d = mock_model(DashboardEntry, :update_attributes => true)
      DashboardEntry.stub(:find) { d }
      d.should_receive(:update_attributes).and_return(d)
      put :update, :id => d.id, :format => :json
      assigns(:dashboard_entry).should eq(d)
      assigns(:status).should eq(200)
    end
    
    it "should return error if could not find dashboard entry" do
      d = mock_model(DashboardEntry, :update_attributes => true)
      DashboardEntry.stub(:find) { nil }
      put :update, :id => d.id, :format => :json
      assigns(:status).should eq(500)
      assigns(:message).should eq("could not find that dashboard_entry")
    end
    
    it "should return error if could not updat dashboard entry" do
      d = mock_model(DashboardEntry, :update_attributes => true)
      DashboardEntry.stub(:find) { d }
      d.should_receive(:update_attributes).and_return(false)
      put :update, :id => d.id, :format => :json
      assigns(:status).should eq(500)
      assigns(:message).should eq("could not update dashboard_entry")
    end
  end
  
end
