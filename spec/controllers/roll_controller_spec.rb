require 'spec_helper'

describe V1::RollController do
  before(:each) do
    @roll = stub_model(Roll)
    Roll.stub!(:find).and_return(@roll)
  end
  
  describe "GET show" do
    it "assigns one roll to @roll" do
      get :show, :format => :json
      assigns(:roll).should eq(@roll)
    end
  end
  
  describe "PUT update" do
    it "updates a roll successfuly" do
      roll = mock_model(Roll, :update_attributes => true)
      Roll.stub(:find) { roll }
      roll.should_receive(:update_attributes).and_return(roll)
      put :update, :id => roll.id, :format => :json
      assigns(:roll).should eq(roll)
      assigns(:status).should eq(200)
    end
    
    it "updates a roll unsuccessfuly returning 500" do
      roll = mock_model(Roll, :update_attributes => false)
      Roll.stub(:find) { roll }
      roll.should_receive(:update_attributes).and_return(false)
      put :update, :id => @roll.id, :format => :json
      assigns(:status).should eq(500)
    end
  end
  
  describe "POST create" do
    before(:each) do
      @user = Factory.create(:user)
      sign_in @user
    end
    
    it "creates and assigns one roll to @roll" do
      Roll.stub!(:new).and_return(@roll)
      @roll.stub(:valid?).and_return(true)
      post :create, :title =>"foo", :thumbnail_url => "http://bar.com", :format => :json
      assigns(:roll).should eq(@roll)
      assigns(:status).should eq(200)
    end
    
    it "returns 500 if user not signed in" do
      sign_out @user
      post :create, :title =>"foo", :thumbnail_url => "http://bar.com", :format => :json
      assigns(:status).should eq(500)
    end
    
    it "returns 500 if there is no title" do
      post :create, :thumbnail_url => "http://foofle", :format => :json
      assigns(:status).should eq(500)
      assigns(:message).should eq("title required")
    end
    
    it "returns 500 if there is no thumbnail_url" do
      post :create, :title => "test", :format => :json
      assigns(:status).should eq(500)
      assigns(:message).should eq("thumbnail_url required")
    end
    
  end
  
  describe "DELETE destroy" do
    it "destroys a roll successfuly" do
      @roll.should_receive(:destroy).and_return(true)
      delete :destroy, :id => @roll.id, :format => :json
      assigns(:status).should eq(200)
    end
    
    it "unsuccessfuly destroys a roll returning 500" do
      @roll.should_receive(:destroy).and_return(false)
      delete :destroy, :id => @roll.id, :format => :json
      assigns(:status).should eq(500)
    end
  end
  
end