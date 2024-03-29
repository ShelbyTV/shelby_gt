require 'spec_helper'

describe V1::BetaInviteController do
  describe "POST create" do
    before(:each) do
      @u1 = Factory.create(:user)
      @u1.public_roll = Factory.create(:roll, :creator => @u1)
      @u1.save
      sign_in @u1
    end
    
    it "should return 200 if the invite is valid" do
      post :create, :to => "to@email.com", :body => "body", :format => :json
      assigns(:status).should eq(200)
    end
    
    it "should return error if the invite is invalid" do
      post :create, :body => "body", :format => :json
      assigns(:status).should eq(409)
    end
    
    it "should return 200 if the invite's to_email_address is valid" do
      post :create, :to => "BAD", :body => "body", :format => :json
      assigns(:status).should eq(409)
    end
    
    it "should return error if the user has not invites availble" do
      @u1.beta_invites_available = 0
      @u1.save
      
      post :create, :to => "to@email.com", :body => "body", :format => :json
      assigns(:status).should eq(409)
    end
  end
end