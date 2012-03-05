require 'spec_helper'

describe V1::UserController do
  describe "GET index" do
    it "assigns all users to @users" do
      u1 = stub_model(User)
      u2 = stub_model(User)
      User.stub(:all) { [u1, u2] }
      get :index, :format => :json
      assigns(:users).should eq([u1, u2])
    end    
  end
  
  describe "GET show" do
    it "assigns one user to @user" do
      u1 = stub_model(User)
      User.stub(:find) { u1 }
      get :show, :format => :json
      assigns(:user).should eq(u1)
    end
  end
  
  describe "PUT update" do
    it "updates a user successfuly" do
      u1 = mock_model(User, :update_attributes => true)
      User.stub(:find) { u1 }
      u1.should_receive(:update_attributes).and_return(u1)
      put :update, :id => "1", :user => {:nickname=>"nick"}, :format => :json
      assigns(:user).should eq(u1)
    end
  end
end