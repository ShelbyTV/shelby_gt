require 'spec_helper'

describe V1::FrameController do
  before(:each) do
    @u1 = Factory.create(:user)
    @u1.upvoted_roll = Factory.create(:roll, :creator => @u1)
    @u1.watch_later_roll = Factory.create(:roll, :creator => @u1)
    @u1.save
    sign_in @u1
    @roll = stub_model(Roll)
    @frame = stub_model(Frame)
    Roll.stub(:find) { @roll }
    Frame.stub(:find) { @frame }
    @roll.stub_chain(:frames, :sort) { [@frame] }
  end  

  describe "GET index" do
    it "assigns all frames in a roll to @frames" do
      get :index, :format => :json
      assigns(:roll).should eq(@roll)
      assigns(:status).should eq(200)
    end
    
    it "returns 400 if cant find roll" do
      Roll.stub(:find) { nil }
      get :index, :format => :json
      assigns(:status).should eq(400)
      assigns(:message).should eq("could not find that roll")
    end
  end
  
  describe "GET show" do
    it "assigns one frame to @frame" do
      get :show, :id => @frame.id, :format => :json
      assigns(:frame).should eq(@frame)
      assigns(:status).should eq(200)
    end
    
    it "returns 400 when cant find frame" do
      Frame.stub(:find) { nil }
      get :show, :format => :json
      assigns(:status).should eq(400)
      assigns(:message).should eq("could not find that frame")
    end
  end
  
  describe "POST upvote" do    
    it "updates a frame successfuly" do
      @frame = Factory.create(:frame)
      @frame.should_receive(:upvote!).with(@u1).and_return(@frame)
      @frame.should_receive(:reload).and_return(@frame)
      
      lambda {
        post :upvote, :id => @frame.id, :format => :json
      }.should change { UserAction.count } .by 1
      
      assigns(:frame).should eq(@frame)
      assigns(:status).should eq(200)
    end
    
    it "updates a frame UNsuccessfuly gracefully" do
      frame = Factory.create(:frame)
      Frame.stub(:find) { nil }
      post :upvote, :id => frame.id, :format => :json
      assigns(:status).should eq(400)
    end
  end
  
  describe "POST watched" do
    it "creates a FrameAction"
    
    it "updates the frame"
    
    it "perhaps creates dashboard entry"
  end
  
  describe "POST add_to_watch_later" do
    before(:each) do    
      @f2 = Factory.create(:frame)
    end
    
    it "creates a UserAction" do
      GT::UserActionManager.should_receive(:watch_later!)
      
      post :add_to_watch_later, :id => @f2.id, :format => :json
    end
    
    it "creates a new Frame" do
      GT::UserActionManager.should_receive(:watch_later!)
      
      lambda {
        post :add_to_watch_later, :id => @f2.id, :format => :json
      }.should change { Frame.count } .by 1
      
      assigns(:new_frame).persisted?.should == true
      assigns(:new_frame).frame_ancestors.include?(@frame.id).should == true
      assigns(:status).should eq(200)
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
      @f1.should_receive(:re_roll).and_return({:frame => @f2})
      
      post :create, :id => @r2.id, :frame_id => @f1.id, :format => :json
      assigns(:status).should eq(200)
      assigns(:frame).should eq(@f2)
    end
    
    it "returns 400 if it can't re_roll" do
      @f1.stub(:re_roll).and_raise(ArgumentError)
      
      post :create, :id => @r2.id, :frame_id => @f1.id, :format => :json
      assigns(:status).should eq(400)
      assigns(:message).should eq("could not re_roll: ArgumentError")
    end

    it "returns 400 if it theres no frame_id to re_roll" do
      post :create, :id => @r2.id, :format => :json
      assigns(:status).should eq(400)
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
    
    it "unsuccessfuly destroys a roll returning 400" do
      frame = mock_model(Frame)
      Frame.stub!(:find).and_return(frame)
      frame.should_receive(:destroy).and_return(false)
      delete :destroy, :id => frame.id, :format => :json
      assigns(:status).should eq(400)
    end
  end
  
end