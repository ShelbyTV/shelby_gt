require 'spec_helper'

describe V1::FrameController do
  before(:each) do
    @roll = stub_model(Roll)
    @frame = stub_model(Frame)
    Roll.stub(:find) { @roll }
    Frame.stub(:find) { @frame }
    @roll.stub(:frames) { [@frame] }
  end  

  describe "GET index" do
    it "assigns all frames in a roll to @frames" do
      get :index, :format => :json
      assigns(:frames).should eq([@frame])
      assigns(:status).should eq(200)
    end
    
    it "returns 500 if cant find roll" do
      Roll.stub(:find) { nil }
      get :index, :format => :json
      assigns(:status).should eq(500)
    end
    
    it "returns 500 if cant find frames in a roll" do
      @roll.stub(:frames) { nil }
      get :index, :format => :json
      assigns(:status).should eq(500)
    end
  end
  
  describe "GET show" do
    it "assigns one frame to @frame" do
      get :show, :id => @frame.id, :format => :json
      assigns(:frame).should eq(@frame)
      assigns(:status).should eq(200)
    end
  end
  
  describe "PUT update" do
    it "updates a frame successfuly" do
      @frame = mock_model(Frame, :update_attributes => true)
      @frame.should_receive(:update_attributes).and_return(@frame)
      put :update, :id => @frame.id, :format => :json
      assigns(:frame).should eq(@frame)
      assigns(:status).should eq(200)
    end
    
    it "updates a frame UNsuccessfuly gracefully" do
      @frame = mock_model(Frame, :update_attributes => true)
      @frame.should_receive(:update_attributes).and_return(false)
      put :update, :id => @frame.id, :format => :json
      assigns(:status).should eq(500)
    end
  end
  
  describe "POST create" do
    it "creates and assigns one frame to @frame" do
      post :create, :format => :json
      assigns(:roll).should eq(r1)
    end
  end
  
  describe "DELETE destroy" do
    it "destroys a roll successfuly" do
      frame = mock_model(Frame)
      Frame.stub!(:find).and_return(frame)
      frame.should_receive(:destroy).and_return(frame)
      delete :destroy, :id => frame.id, :format => :json
      assigns(:status).should eq(200)
    end
    
    it "unsuccessfuly destroys a roll returning 500" do
      frame = mock_model(Frame)
      Frame.stub!(:find).and_return(frame)
      frame.should_receive(:destroy).and_return(false)
      delete :destroy, :id => frame.id, :format => :json
      assigns(:status).should eq(500)
    end
  end
  
end