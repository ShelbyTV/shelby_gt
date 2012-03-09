require 'spec_helper'

describe V1::FrameController do
  before(:each) do
    @u1 = Factory.create(:user)
    sign_in @u1
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
      assigns(:message).should eq("could not find that roll")
    end
    
    it "returns 500 if cant find frames in a roll" do
      @roll.stub(:frames) { nil }
      get :index, :format => :json
      assigns(:status).should eq(500)
      assigns(:message).should eq("could not find the frames from that roll")
    end
  end
  
  describe "GET show" do
    it "assigns one frame to @frame" do
      get :show, :id => @frame.id, :format => :json
      assigns(:frame).should eq(@frame)
      assigns(:status).should eq(200)
    end
    
    it "returns 500 when cant find frame" do
      Frame.stub(:find) { nil }
      get :show, :format => :json
      assigns(:status).should eq(500)
      assigns(:message).should eq("could not find that frame")
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
    before(:each) do
      @f1 = stub_model(Frame)
      @f1.conversation = stub_model(Conversation)

      @r2 = stub_model(Roll)
      @f2 = stub_model(Frame)

      Frame.stub(:find) { @f1 }      
      Roll.stub(:find) { @r2 }
    end
    
    it "re_roll and returns one frame to @frame" do      
      @f1.should_receive(:re_roll).and_return(@f2)
      
      post :create, :id => @r2.id, :frame_id => @f1.id, :format => :json
      assigns(:frame).should eq(@f2)
      assigns(:status).should eq(200)
    end
    
    it "returns 500 if it can't re_roll" do
      @f1.stub(:re_roll).and_raise(ArgumentError)
      
      post :create, :id => @r2.id, :frame_id => @f1.id, :format => :json
      assigns(:status).should eq(500)
      assigns(:message).should eq("could not re_roll: ArgumentError")
    end

    it "returns 500 if it theres no frame_id to re_roll" do
      post :create, :id => @r2.id, :format => :json
      assigns(:status).should eq(500)
      assigns(:message).should eq("you haven't built me to do anything else yet...")
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