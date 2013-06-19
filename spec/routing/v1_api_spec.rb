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
    it "routes for user index" do
      { :get => "/v1/user" }.should route_to(
        :controller => "v1/user",
        :action => "index",
        :format => "json"
      )
    end

    it "routes for user GET" do
      { :get => "/v1/user/1" }.should route_to(
        :controller => "v1/user",
        :action => "show",
        :format => "json",
        :id => "1"
      )
    end

    it "routes for user GET with nickname" do
      { :get => "/v1/user/nickname" }.should route_to(
        :controller => "v1/user",
        :action => "show",
        :format => "json",
        :id => "nickname"
      )
    end

    it "routes for user GET with nickname that includes a dot" do
      { :get => "/v1/user/nick.name" }.should route_to(
        :controller => "v1/user",
        :action => "show",
        :format => "json",
        :id => "nick.name"
      )
    end

    it "routes for signed_in GET" do
      { :get => "/v1/signed_in" }.should route_to(
        :controller => "v1/user",
        :action => "signed_in",
        :format => "json"
      )
    end

    it "route for incrementing session count PUT" do
      { :put => "/v1/log_session" }.should route_to(
        :controller => "v1/user",
        :action => "log_session",
        :format => "json"
      )
    end

    it "routes for GET users rolls following" do
      { :get => "/v1/user/1/rolls/following" }.should route_to(
        :controller => "v1/user_metal",
        :action => "roll_followings",
        :format => "json",
        :id => "1"
      )
    end

    it "routes for GET users rolls collaborating" do
      { :get => "/v1/user/1/rolls/postable" }.should route_to(
        :controller => "v1/user_metal",
        :action => "roll_followings",
        :format => "json",
        :id => "1",
        :postable => true
      )
    end

    it "route for getting validity of users fb auth token" do
      { :get => "/v1/user/1/is_token_valid" }.should route_to(
        :controller => "v1/user",
        :action => "valid_token",
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

    it "routes for POST to users dashboard with frame" do
      { :post => "/v1/user/1/dashboard_entry" }.should route_to(
        :controller => "v1/user",
        :action => "add_dashboard_entry",
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
        :controller => "v1/dashboard_entries_metal",
        :format => "json",
        :action => "index"
      )
    end

    it "routes for GET" do
      { :get => "/v1/user/1/dashboard" }.should route_to(
        :controller => "v1/dashboard_entries_metal",
        :format => "json",
        :user_id => "1",
        :action => "index_for_user"
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
    it "routes for GET frame" do
      { :get => "/v1/frame/1" }.should route_to(
        :controller => "v1/frame",
        :action => "show",
        :format => "json",
        :id => "1"
      )
    end

    it "routes for GET short_link" do
      { :get => "/v1/frame/1/short_link" }.should route_to(
        :controller => "v1/frame",
        :action => "short_link",
        :format => "json",
        :frame_id => "1"
      )
    end

    it "GET INDEX of personal_roll" do
      { :get => "/v1/user/1/rolls/personal/frames" }.should route_to(
        :controller => "v1/frame_metal",
        :action => "index_for_users_public_roll",
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

    it "routes for PUT like" do
      { :put => "/v1/frame/1/like" }.should route_to(
        :controller => "v1/frame",
        :action => "like",
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

    it "routes for GET associated" do
      { :get => "/v1/roll/1/associated" }.should route_to(
        :controller => "v1/roll",
        :action => "index_associated",
        :format => "json",
        :roll_id => "1"
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

    it "routes to Explore roll" do
      { :get => "/v1/roll/explore" }.should route_to(
        :controller => "v1/roll",
        :action => "explore",
        :format => "json"
      )
    end

    it "routes to Featured" do
      { :get => "/v1/roll/featured" }.should route_to(
        :controller => "v1/roll",
        :action => "featured",
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

    it "routes for GET viewed" do
      { :get => "/v1/video/viewed" }.should route_to(
        :controller => "v1/video",
        :action => "viewed",
        :format => "json"
      )
    end

    it "routes for GET queued" do
      { :get => "/v1/video/queued" }.should route_to(
        :controller => "v1/video",
        :action => "queued",
        :format => "json"
      )
    end

    it "routes for PUT unplayable" do
      { :put => "/v1/video/1/unplayable" }.should route_to(
        :controller => "v1/video",
        :action => "unplayable",
        :video_id => "1",
        :format => "json"
      )
    end

    it "routes for PUT fix_if_necessary" do
      { :put => "/v1/video/1/fix_if_necessary" }.should route_to(
        :controller => "v1/video",
        :action => "fix_if_necessary",
        :video_id => "1",
        :format => "json"
      )
    end

    it "routes for GET search" do
      { :get => "/v1/video/search" }.should route_to(
        :controller => "v1/video",
        :action => "search",
        :format => "json"
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

describe V1::DiscussionRollController do
  describe "routing" do
    it "routes for INDEX" do
      { :get => '/v1/discussion_roll' }.should route_to(
        :controller => "v1/discussion_roll",
        :action => "index",
        :format => "json"
      )
    end

    it "routes for GET" do
      { :get => "/v1/discussion_roll/1" }.should route_to(
        :controller => "v1/discussion_roll",
        :action => "show",
        :format => "json",
        :id => "1"
      )
    end

    it "routes for POST" do
      { :post => "/v1/discussion_roll" }.should route_to(
        :controller => "v1/discussion_roll",
        :action => "create",
        :format => "json"
      )
    end

    it "routes for POST message" do
      { :post => "/v1/discussion_roll/1/messages" }.should route_to(
        :controller => "v1/discussion_roll",
        :action => "create_message",
        :format => "json",
        :discussion_roll_id => "1"
      )
    end
  end
end

describe V1::BetaInviteController do
  describe "routing" do
    it "routes for POST" do
      { :post => "/v1/beta_invite" }.should route_to(
        :controller => "v1/beta_invite",
        :action => "create",
        :format => "json"
      )
    end
  end
end

describe V1::TwitterController do
  describe "routing" do
    it "routes for POST to /follow" do
      { :post => "/v1/twitter/follow/twitter_user_name" }.should route_to(
        :controller => "v1/twitter",
        :action => "follow",
        :format => "json",
        :twitter_user_name => "twitter_user_name"
      )
    end
  end
end


describe V1::RemoteControlController do
  describe "routing" do
      it "routes for GET" do
        { :get => "/v1/remote_control/1" }.should route_to(
          :controller => "v1/remote_control",
          :action => "show",
          :format => "json",
          :id => "1"
        )
      end

      it "routes for PUT" do
        { :put => "/v1/remote_control/1" }.should route_to(
          :controller => "v1/remote_control",
          :action => "update",
          :id => "1",
          :format => "json"
        )
      end

      it "routes for POST" do
        { :post => "/v1/remote_control" }.should route_to(
          :controller => "v1/remote_control",
          :action => "create",
          :format => "json"
        )
      end

    end
end

describe V1::JavascriptErrorsController do
  describe "routing" do
    it "routes for create" do
      { :post => "/v1/js_err" }.should route_to(
        :controller => "v1/javascript_errors",
        :action => "create",
        :format => "json")
    end
  end
end
