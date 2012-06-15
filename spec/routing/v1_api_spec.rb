require 'spec_helper'

describe V1::TokenController do
  describe "routing" do
    it "routes for token create" do
      { :post => "/v1/token" }.should route_to(
        :controller => "v1/token",
        :action => "create",
        :format => "json")
    end
    
    it "routes for token destroy" do
      { :delete => "/v1/token/1" }.should route_to(
        :controller => "v1/token",
        :action => "destroy",
        :id => "1",
        :format => "json")
    end
  end
end

describe V1::UserController do
  describe "routing" do
    it "routes for user GET" do
      { :get => "/v1/user/1" }.should route_to(
        :controller => "v1/user",
        :action => "show",
        :format => "json",
        :id => "1"
      )
    end
    
    it "routes for signed_in GET" do
      { :get => "/v1/signed_in" }.should route_to(
        :controller => "v1/user",
        :action => "signed_in",
        :format => "json"
      )
    end

    it "routes for GET users rolls following" do
      { :get => "/v1/user/1/rolls/following" }.should route_to(
        :controller => "v1/user",
        :action => "roll_followings",
        :format => "json",
        :id => "1"
      )
    end
    
    it "routes for PUT" do
      { :put => "/v1/user/1" }.should route_to(
        :controller => "v1/user",
        :action => "update",
        :format => "json",
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
        :format => "json",
        :action => "index"
      )
    end 

    it "routes for PUT" do
      { :put => "/v1/dashboard/1" }.should route_to(
        :controller => "v1/dashboard_entries",
        :action => "update",
        :format => "json",
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
        :format => "json",
        :id => "1"
      )
    end 
    
    it "GET INDEX of personal_roll" do
      { :get => "/v1/user/1/rolls/personal/frames" }.should route_to(
        :controller => "v1/frame",
        :action => "index_for_users_public_roll",
        :format => "json",
        :user_id => "1"
      )
    end

    it "GET INDEX of heart_roll" do
      { :get => "/v1/user/1/rolls/heart/frames" }.should route_to(
        :controller => "v1/frame",
        :action => "index_for_users_heart_roll",
        :format => "json",
        :user_id => "1"
      )
    end

    it "routes for POST upvote" do
      { :post => "/v1/frame/1/upvote" }.should route_to(
        :controller => "v1/frame",
        :action => "upvote",
        :format => "json",
        :frame_id => "1"
      )
    end
    
    it "routes for POST add_to_watch_later" do
      { :post => "/v1/frame/1/add_to_watch_later" }.should route_to(
        :controller => "v1/frame",
        :action => "add_to_watch_later",
        :format => "json",
        :frame_id => "1"
      )
    end
    
    it "routes for POST watched" do
      { :post => "/v1/frame/1/watched" }.should route_to(
        :controller => "v1/frame",
        :action => "watched",
        :format => "json",
        :frame_id => "1"
      )
    end
    
    it "routes for share frame POST" do
      { :post => "/v1/frame/1/share" }.should route_to(
        :controller => "v1/frame",
        :action => "share",
        :format => "json",
        :frame_id => "1"
      )
    end
    
    it "routes for DELETE" do
      { :delete => "/v1/frame/1" }.should route_to(
        :controller => "v1/frame",
        :action => "destroy",
        :format => "json",
        :id => "1"
      )
    end 
    
    it "routes for POST" do
      { :post => "/v1/roll/1/frames" }.should route_to(
        :controller => "v1/frame",
        :action => "create",
        :format => "json",
        :roll_id => "1"
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
        :format => "json",
        :id => "1"
      )
    end 
    
    it "GET personal_roll" do
      { :get => "/v1/user/1/rolls/personal" }.should route_to(
        :controller => "v1/roll",
        :action => "show_users_public_roll",
        :format => "json",
        :user_id => "1"
      )
    end 
    
    it "GET hearted roll" do
      { :get => "/v1/user/1/rolls/hearted" }.should route_to(
        :controller => "v1/roll",
        :action => "show_users_heart_roll",
        :format => "json",
        :user_id => "1"
      )
    end
    
    it "route to browser roll" do
      { :get => "/v1/roll/browse" }.should route_to(
        :controller => "v1/roll",
        :action => "browse",
        :format => "json"
      )
    end

    it "routes for PUT" do
      { :put => "/v1/roll/1" }.should route_to(
        :controller => "v1/roll",
        :action => "update",
        :format => "json",
        :id => "1"
      )
    end 
    
    it "routes for share roll POST" do
      { :post => "/v1/roll/1/share" }.should route_to(
        :controller => "v1/roll",
        :action => "share",
        :format => "json",
        :roll_id => "1"
      )
    end

    it "routes for join roll POST" do
      { :post => "/v1/roll/1/join" }.should route_to(
        :controller => "v1/roll",
        :action => "join",
        :format => "json",
        :roll_id => "1"
      )
    end

    it "routes for create leave POST" do
      { :post => "/v1/roll/1/leave" }.should route_to(
        :controller => "v1/roll",
        :action => "leave",
        :format => "json",
        :roll_id => "1"
      )
    end
    
    it "routes for DELETE" do
      { :delete => "/v1/roll/1" }.should route_to(
        :controller => "v1/roll",
        :action => "destroy",
        :format => "json",
        :id => "1"
      )
    end 
  end
end

describe V1::Roll::GeniusController do
  describe "routing" do
    it "routes for PUT" do
      { :post => "/v1/roll/genius" }.should route_to(
        :controller => "v1/roll/genius",
        :action => "create",
        :format => "json"
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
        :format => "json",
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
        :format => "json",
        :id => "1"
      )
    end 

    it "routes for POST" do
      { :post => "/v1/conversation/1/messages" }.should route_to(
        :controller => "v1/messages",
        :action => "create",
        :format => "json",
        :conversation_id => "1"
      )
    end 
    
    it "routes for DELETE" do
      { :delete => "/v1/conversation/1/messages/4" }.should route_to(
        :controller => "v1/messages",
        :action => "destroy",
        :format => "json",
        :conversation_id => "1",
        :id => "4"
      )
    end 
  end
end
