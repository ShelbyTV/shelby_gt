require 'spec_helper'

describe "User" do
  #PUT    /v1/user/:id(.:format)                                   v1/user#update {:format=>"json"}
  it "routes for update" do
    { :get => "/v1/PUT/user/33" }.should route_to(
      :controller => "v1/user",
      :action => "update",
      :format => "json",
      :id => "33"
    )
  end
end


describe "Roll" do  
  # POST   /v1/roll/:roll_id/share(.:format)                        v1/roll#share {:format=>"json"}
  it "routes for share" do
    { :get => "/v1/POST/roll/33/share" }.should route_to(
      :controller => "v1/roll",
      :action => "share",
      :format => "json",
      :roll_id => "33"
    )
  end
  
  # POST   /v1/roll/:roll_id/join(.:format)                         v1/roll#join {:format=>"json"}
  it "routes for join" do
    { :get => "/v1/POST/roll/33/join" }.should route_to(
      :controller => "v1/roll",
      :action => "join",
      :format => "json",
      :roll_id => "33"
    )
  end
  
  # POST   /v1/roll/:roll_id/leave(.:format)                        v1/roll#leave {:format=>"json"}
  it "routes for leave" do
    { :get => "/v1/POST/roll/33/leave" }.should route_to(
      :controller => "v1/roll",
      :action => "leave",
      :format => "json",
      :roll_id => "33"
    )
  end
  
  # POST   /v1/roll(.:format)                                       v1/roll#create {:format=>"json"}
  it "routes for create" do
    { :get => "/v1/POST/roll" }.should route_to(
      :controller => "v1/roll",
      :action => "create",
      :format => "json"
    )
  end
  
  # PUT    /v1/roll/:id(.:format)                                   v1/roll#update {:format=>"json"}
  it "routes for update" do
    { :get => "/v1/PUT/roll/33" }.should route_to(
      :controller => "v1/roll",
      :action => "update",
      :format => "json",
      :id => "33"
    )
  end
  
  # DELETE /v1/roll/:id(.:format)                                   v1/roll#destroy {:format=>"json"}
  it "routes for DELETE" do
    { :get => "/v1/DELETE/roll/33" }.should route_to(
      :controller => "v1/roll",
      :action => "destroy",
      :format => "json",
      :id => "33"
    )
  end
  
end

describe "Frame" do
  
  # POST   /v1/roll/:roll_id/frames(.:format)                       v1/frame#create {:format=>"json"}
  it "routes for create" do
    { :get => "/v1/POST/roll/33/frames" }.should route_to(
      :controller => "v1/frame",
      :action => "create",
      :format => "json",
      :roll_id => "33"
    )
  end
  
  # POST   /v1/frame/:frame_id/upvote(.:format)                     v1/frame#upvote {:format=>"json"}
  it "routes for upvote" do
    { :get => "/v1/POST/frame/33/upvote" }.should route_to(
      :controller => "v1/frame",
      :action => "upvote",
      :format => "json",
      :frame_id => "33"
    )
  end
  
  # POST   /v1/frame/:frame_id/add_to_watch_later(.:format)         v1/frame#add_to_watch_later {:format=>"json"}
  it "routes for add to watch later" do
    { :get => "/v1/POST/frame/33/add_to_watch_later" }.should route_to(
      :controller => "v1/frame",
      :action => "add_to_watch_later",
      :format => "json",
      :frame_id => "33"
    )
  end
  
  # POST   /v1/frame/:frame_id/watched(.:format)                    v1/frame#watched {:format=>"json"}
  it "routes for watched" do
    { :get => "/v1/POST/frame/33/watched" }.should route_to(
      :controller => "v1/frame",
      :action => "watched",
      :format => "json",
      :frame_id => "33"
    )
  end
  
  # POST   /v1/frame/:frame_id/share(.:format)                      v1/frame#share {:format=>"json"}
  it "routes for share" do
    { :get => "/v1/POST/frame/33/share" }.should route_to(
      :controller => "v1/frame",
      :action => "share",
      :format => "json",
      :frame_id => "33"
    )
  end
  
  # DELETE /v1/frame/:id(.:format)                                  v1/frame#destroy {:format=>"json"}
  it "routes for DELETE" do
    { :get => "/v1/DELETE/frame/33" }.should route_to(
      :controller => "v1/frame",
      :action => "destroy",
      :format => "json",
      :id => "33"
    )
  end
  
end

describe "Videos" do
  
  # PUT   /v1/video/:video_id/unplayable(.:format)                        v1/video#unplayable {:format=>"json"}
  it "routes for PUT unplayable" do
    { :get => "/v1/PUT/video/33/unplayable" }.should route_to(
      :controller => "v1/video",
      :action => "unplayable",
      :format => "json",
      :video_id => "33"
    )
  end
  
end

describe "DashboardEntries" do
  
  # PUT    /v1/dashboard/:video_id(.:format)                              v1/dashboard_entries#update {:format=>"json"}
  it "routes for PUT" do
    { :get => "/v1/PUT/dashboard/33" }.should route_to(
      :controller => "v1/dashboard_entries",
      :action => "update",
      :format => "json",
      :id => "33"
    )
  end
  
end

describe "Messages" do
  
  # POST   /v1/conversation/:conversation_id/messages(.:format)     v1/messages#create {:format=>"json"}
  it "routes for create" do
    { :get => "/v1/POST/conversation/33/messages" }.should route_to(
      :controller => "v1/messages",
      :action => "create",
      :format => "json",
      :conversation_id => "33"
    )
  end
  
  # DELETE /v1/conversation/:conversation_id/messages/:id(.:format) v1/messages#destroy {:format=>"json"}
  it "routes for DELETE" do
    { :get => "/v1/DELETE/conversation/33/messages/3333" }.should route_to(
      :controller => "v1/messages",
      :action => "destroy",
      :format => "json",
      :conversation_id => "33",
      :id => "3333"
    )
  end
  
end

describe "BetaInvite" do
  
  # POST   /v1/beta_invite(.:format)                                       v1/beta_invite#create {:format=>"json"}
  it "routes for create" do
    { :get => "/v1/POST/beta_invite" }.should route_to(
      :controller => "v1/beta_invite",
      :action => "create",
      :format => "json"
    )
  end
    
end

describe "GtInterest" do
  
  # POST   /v1/gt_interest(.:format)                                v1/gt_interest#create {:format=>"json"}
  it "routes for create" do
    { :get => "/v1/POST/gt_interest" }.should route_to(
      :controller => "v1/gt_interest",
      :action => "create",
      :format => "json"
    )
  end
  
end

describe "Twitter" do
  
  # POST   /v1/twitter/follow/:twitter_user_name(.:format)                 v1/twitter/#follow {:format=>"json"}
  it "routes for POST /follow" do
    { :get => "/v1/POST/twitter/follow/some_user_name" }.should route_to(
      :controller => "v1/twitter",
      :action => "follow",
      :twitter_user_name => "some_user_name",
      :format => "json"
    )
  end
end