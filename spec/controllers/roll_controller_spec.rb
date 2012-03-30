require 'spec_helper'

describe V1::RollController do
  before(:each) do
    @u1 = Factory.create(:user)
    sign_in @u1
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
      roll.should_receive(:update_attributes!).and_return(roll)
      put :update, :id => roll.id, :public => false , :format => :json
      assigns(:roll).should eq(roll)
      assigns(:status).should eq(200)
    end
    
    it "updates a roll unsuccessfuly returning 404" do
      roll = mock_model(Roll, :update_attributes => true)
      Roll.stub(:find) { roll }
      roll.should_receive(:update_attributes!).and_raise(ArgumentError)
      put :update, :id => @roll.id, :public => false, :format => :json
      assigns(:status).should eq(404)
    end
  end
  
  describe "POST create" do
    before(:each) do
      @roll = stub_model(Roll)
      Roll.stub!(:find).and_return(@roll)
    end
    
    it "creates and assigns one roll to @roll" do
      Roll.stub!(:new).and_return(@roll)
      @roll.stub(:valid?).and_return(true)
      post :create, :title =>"foo", :thumbnail_url => "http://bar.com", :format => :json
      assigns(:roll).should eq(@roll)
      assigns(:status).should eq(200)
    end
    
    it "returns 404 if user not signed in" do
      sign_out @u1
      post :create, :title =>"foo", :thumbnail_url => "http://bar.com", :format => :json
      response.should_not be_success
    end
    
    it "returns 404 if there is no title" do
      sign_in @u1
      post :create, :thumbnail_url => "http://foofle", :format => :json
      assigns(:status).should eq(404)
      assigns(:message).should eq("title required")
    end
    
    it "returns 404 if there is no thumbnail_url" do
      sign_in @u1
      post :create, :title => "test", :format => :json
      assigns(:status).should eq(404)
      assigns(:message).should eq("thumbnail_url required")
    end
    
  end
  
  describe "POST share" do
    before(:each) do
      sign_in @u1
      @roll = stub_model(Roll)
      Roll.stub!(:find).and_return(@roll)
    end
    
    it "should return 200 if the user posts succesfully to destination" do
      post :share, :destination => ["twitter"], :comment => "testing", :format => :json
      assigns(:status).should eq(200)      
    end
    
    it "should return 404 if destination is not an array" do
      post :share, :destination => "twitter", :comment => "testing", :format => :json
      assigns(:status).should eq(404)
    end
    
    it "should return 404 if the user cant post to the destination" do
      post :share, :destination => ["facebook"], :comment => "testing", :format => :json
      assigns(:status).should eq(404)
      assigns(:message).should eq("that user cant post to that destination")      
    end
    
    it "should not post if the destination is not supported" do
      post :share, :destination => ["awesome_service"], :comment => "testing", :format => :json
      assigns(:status).should eq(404)
      assigns(:message).should eq("we dont support that destination yet :(")
    end
    
    it "should return 404 if a comment or destination is not present" do
      post :share, :destination => ["twitter"], :format => :json
      assigns(:status).should eq(404)
      
      post :share, :comment => "testing", :format => :json
      assigns(:status).should eq(404)
      
      assigns(:message).should eq("a destination and a comment is required to post")
    end
    
    it "should return 404 if roll is private" do
      roll = stub_model(Roll, :public => false)
      Roll.stub!(:find).and_return(roll)
      post :share, :destination => ["twitter"], :comment => "testing", :format => :json
      assigns(:status).should eq(404)
      assigns(:message).should eq("that roll is private, can not share")      
    end
    
    it "should return 404 if roll not found" do
      Roll.stub!(:find).and_return(nil)
      post :share, :destination => ["twitter"], :comment => "testing", :format => :json
      assigns(:status).should eq(404)
      assigns(:message).should eq("could not find that roll")
    end
    
  end
  
  describe "DELETE destroy" do
    before(:each) do
      @u1 = Factory.create(:user)
      sign_in @u1
      
      @roll = stub_model(Roll)
      Roll.stub!(:find).and_return(@roll)
    end
    
    it "destroys a roll successfuly" do
      @roll.should_receive(:destroy).and_return(true)
      delete :destroy, :id => @roll.id, :format => :json
      assigns(:status).should eq(200)
    end
    
    it "unsuccessfuly destroys a roll returning 404" do
      @roll.should_receive(:destroy).and_return(false)
      delete :destroy, :id => @roll.id, :format => :json
      assigns(:status).should eq(404)
    end
  end
  
end