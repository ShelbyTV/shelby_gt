require 'spec_helper'

describe V1::UserController do
  describe "routing" do
    it "routes for GET" do
      { :get => "/v1/user/1" }.should route_to(
        :controller => "v1/user",
        :action => "show",
        :id => "1"
      )
    end 

    it "routes for PUT" do
      { :put => "/v1/user/1" }.should route_to(
        :controller => "v1/user",
        :action => "update",
        :id => "1"
      )
    end 
  end
end

describe V1::DashboardEntriesController do
  describe "routing" do
    it "routes for GET" do
      { :get => "/v1/dashboard" }.should route_to(
        :controller => "v1/dashboard_entries",
        :action => "index"
      )
    end 

    it "routes for PUT" do
      { :put => "/v1/dashboard/1" }.should route_to(
        :controller => "v1/dashboard_entries",
        :action => "update",
        :id => "1"
      )
    end 
  end
end

describe V1::FrameController do
  describe "routing" do
    it "routes for GET" do
      { :get => "/v1/frame/1" }.should route_to(
        :controller => "v1/frame",
        :action => "show",
        :id => "1"
      )
    end 

    it "routes for PUT" do
      { :put => "/v1/frame/1" }.should route_to(
        :controller => "v1/frame",
        :action => "update",
        :id => "1"
      )
    end 
    
    it "routes for DELETE" do
      { :delete => "/v1/frame/1" }.should route_to(
        :controller => "v1/frame",
        :action => "destroy",
        :id => "1"
      )
    end 
    
    it "routes for POST" do
      { :post => "/v1/roll/1/frames" }.should route_to(
        :controller => "v1/frame",
        :action => "create",
        :id => "1"
      )
    end
  end
end

describe V1::RollController do
  describe "routing" do
    it "routes for GET" do
      { :get => "/v1/roll/1" }.should route_to(
        :controller => "v1/roll",
        :action => "show",
        :id => "1"
      )
    end 

    it "routes for PUT" do
      { :put => "/v1/roll/1" }.should route_to(
        :controller => "v1/roll",
        :action => "update",
        :id => "1"
      )
    end 
    
    it "routes for DELETE" do
      { :delete => "/v1/roll/1" }.should route_to(
        :controller => "v1/roll",
        :action => "destroy",
        :id => "1"
      )
    end 
  end
end

describe V1::VideoController do
  describe "routing" do
    it "routes for GET" do
      { :get => "/v1/video/1" }.should route_to(
        :controller => "v1/video",
        :action => "show",
        :id => "1"
      )
    end 
  end
end

describe V1::ConversationController do
  describe "routing" do
    it "routes for GET" do
      { :get => "/v1/conversation/1" }.should route_to(
        :controller => "v1/conversation",
        :action => "show",
        :id => "1"
      )
    end 

    it "routes for POST" do
      { :post => "/v1/conversation/1/messages" }.should route_to(
        :controller => "v1/messages",
        :action => "create",
        :conversation_id => "1"
      )
    end 
    
    it "routes for DELETE" do
      { :delete => "/v1/conversation/1/messages/4" }.should route_to(
        :controller => "v1/messages",
        :action => "destroy",
        :conversation_id => "1",
        :id => "4"
      )
    end 
  end
end