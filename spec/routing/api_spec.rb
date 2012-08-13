require 'spec_helper'

describe AdminController do
  describe "routing" do
    it "routes for user GET" do
      { :get => "/admin/user/1" }.should route_to(
        :controller => "admin",
        :action => "user",
        :id => '1')
    end
    
    it "routes for user GET with nickname" do
      { :get => "/admin/user/nickname" }.should route_to(
        :controller => "admin",
        :action => "user",
        :id => 'nickname')
    end
    
    it "routes for user GET with nickname that includes dots" do
      { :get => "/admin/user/nick.name" }.should route_to(
        :controller => "admin",
        :action => "user",
        :id => 'nick.name')
    end
  end
end

describe AuthenticationsController do
  describe "routing" do
    it "routes for login POST" do
      { :post => "/authentications/login" }.should route_to(
        :controller => "authentications",
        :action => "login")
    end
  end
end