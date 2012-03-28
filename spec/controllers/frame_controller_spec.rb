require 'spec_helper'
require 'video_manager'

describe V1::FrameController do
  before(:each) do
    @u1 = Factory.create(:user)
    @u1.upvoted_roll = Factory.create(:roll, :creator => @u1)
    @u1.watch_later_roll = Factory.create(:roll, :creator => @u1)
    @u1.viewed_roll = Factory.create(:roll, :creator => @u1)
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
    
    it "returns 404 if cant find roll" do
      Roll.stub(:find) { nil }
      get :index, :format => :json
      assigns(:status).should eq(404)
      assigns(:message).should eq("could not find that roll")
    end
  end
  
  describe "GET show" do
    it "assigns one frame to @frame" do
      get :show, :frame_id => @frame.id, :format => :json
      assigns(:frame).should eq(@frame)
      assigns(:status).should eq(200)
    end
    
    it "returns 404 when cant find frame" do
      Frame.stub(:find) { nil }
      get :show, :format => :json
      assigns(:status).should eq(404)
      assigns(:message).should eq("could not find that frame")
    end
  end
  
  describe "POST upvote" do    
    it "updates a frame successfuly" do
      @frame = Factory.create(:frame)
      @frame.should_receive(:upvote!).with(@u1).and_return(@frame)
      @frame.should_receive(:reload).and_return(@frame)
      
      lambda {
        post :upvote, :frame_id => @frame.id, :format => :json
      }.should change { UserAction.count } .by 1
      
      assigns(:frame).should eq(@frame)
      assigns(:status).should eq(200)
    end
    
    it "updates a frame UNsuccessfuly gracefully" do
      frame = Factory.create(:frame)
      Frame.stub(:find) { nil }
      post :upvote, :frame_id => frame.id, :format => :json
      assigns(:status).should eq(404)
    end
  end
  
  describe "POST watched" do
    it "creates a UserAction w/ all params" do
      GT::UserActionManager.should_receive(:view!)
      Frame.should_receive(:roll_includes_ancestor_of_frame?).and_return(false)
      @frame.should_receive(:reload).and_return(@frame)
      
      post :watched, :frame_id => @frame.id, :start_time => "0", :end_time => "14", :format => :json
    end
    
    it "creates a new frame w/ all params" do
      GT::UserActionManager.should_receive(:view!)
      Frame.should_receive(:roll_includes_ancestor_of_frame?).and_return(false)
      @frame.should_receive(:reload).and_return(@frame)
      
      lambda {
        post :watched, :frame_id => @frame.id, :start_time => "0", :end_time => "14", :format => :json
      }.should change { Frame.count } .by 1
      
      assigns(:new_frame).persisted?.should == true
      assigns(:new_frame).frame_ancestors.include?(@frame.id).should == true
      assigns(:status).should eq(200)
    end
    
    it "shouldn't need a logged in user" do
      GT::UserActionManager.should_receive(:view!)
      Frame.should_not_receive(:view!)
      @frame.should_not_receive(:reload)
      
      sign_out @u1
      
      post :watched, :frame_id => @frame.id, :start_time => "0", :end_time => "14", :format => :json
    end
    
    it "shouldn't need start and end times" do
      GT::UserActionManager.should_not_receive(:view!)
      Frame.should_receive(:roll_includes_ancestor_of_frame?).and_return(false)
      @frame.should_receive(:reload).and_return(@frame)
      
      lambda {
        post :watched, :frame_id => @frame.id, :format => :json
      }.should change { Frame.count } .by 1
      
      assigns(:new_frame).persisted?.should == true
      assigns(:new_frame).frame_ancestors.include?(@frame.id).should == true
      assigns(:status).should eq(200)
    end
    
    it "should return 404 if Frame can't be found" do
      Frame.should_receive(:find).with("somebadid").and_return(nil)
      lambda {
        post :watched, :frame_id => "somebadid", :format => :json
      }.should_not change { Frame.count }
      
      assigns(:status).should eq(404)
    end
  end
  
  describe "POST add_to_watch_later" do
    before(:each) do    
      @f2 = Factory.create(:frame)
    end
    
    it "creates a UserAction" do
      GT::UserActionManager.should_receive(:watch_later!)
      
      post :add_to_watch_later, :frame_id => @f2.id, :format => :json
    end
    
    it "creates a new Frame" do
      GT::UserActionManager.should_receive(:watch_later!)
      
      lambda {
        post :add_to_watch_later, :frame_id => @f2.id, :format => :json
      }.should change { Frame.count } .by 1
      
      assigns(:new_frame).persisted?.should == true
      assigns(:new_frame).frame_ancestors.include?(@frame.id).should == true
      assigns(:status).should eq(200)
    end
  end
  
  describe "POST create" do
    before(:each) do
      @video_url = CGI::escape("http://some.video.url.com/of_a_movie_i_like")
      @message = "boy this is awesome"
      @video = Factory.create(:video, :source_url => @video_url)
      
      @f1 = stub_model(Frame, :video => @video)
      @f1.conversation = stub_model(Conversation)

      @r2 = stub_model(Roll)
      @f2 = stub_model(Frame)

      Frame.stub(:find) { @f1 }
      Roll.stub(:find) { @r2 }
    end

    it "should create a new frame if given valid source, video_url and text params" do
      GT::VideoManager.stub(:get_or_create_videos_for_url).with(@video_url).and_return(@video)
      GT::Framer.stub(:create_frame_from_url).and_return({:frame => @f1})
      post :create, :roll_id => @r2.id, :url => @video_url, :text => @message, :source => "webapp", :format => :json
      assigns(:status).should eq(200)
      assigns(:frame).should eq(@f1)
    end
    
    it "should create a new frame if given video_url and text params" do
      GT::VideoManager.stub(:get_or_create_videos_for_url).with(@video_url).and_return(@video)
      GT::Framer.stub(:create_frame_from_url).and_return({:frame => @f1})
      post :create, :roll_id => @r2.id, :url => @video_url, :text => @message, :format => :json
      assigns(:status).should eq(200)
      assigns(:frame).should eq(@f1)
    end
    
    it "should return a new frame if a video_url is given but a message is not" do
      GT::VideoManager.stub(:get_or_create_videos_for_url).with(@video_url).and_return(@video)
      GT::Framer.stub(:create_frame_from_url).and_return({:frame => @f1})
      post :create, :roll_id => @r2.id, :url => @video_url, :format => :json
      assigns(:status).should eq(200)
      assigns(:frame).should eq(@f1)
    end
    
    it "should be ok if action is f-d up" do
      GT::VideoManager.stub(:get_or_create_videos_for_url).with(@video_url).and_return(@video)
      GT::Framer.stub(:create_frame_from_url).and_return({:frame => @f1})
      post :create, :roll_id => @r2.id, :url => @video_url, :source => "fucked_up", :format => :json
      assigns(:status).should eq(404)
    end
    
    it "should re_roll and returns one frame to @frame if given a frame_id param" do
      @f1.should_receive(:re_roll).and_return({:frame => @f2})
      
      post :create, :roll_id => @r2.id, :frame_id => @f1.id, :format => :json
      assigns(:status).should eq(200)
      assigns(:frame).should eq(@f2)
    end
    
    it "returns 404 if it can't re_roll" do
      @f1.stub(:re_roll).and_raise(ArgumentError)
      
      post :create, :roll_id => @r2.id, :frame_id => @f1.id, :format => :json
      assigns(:status).should eq(404)
      assigns(:message).should eq("could not re_roll: ArgumentError")
    end

    it "returns 404 if it theres no frame_id to re_roll or no video_url to make into a frame" do
      post :create, :roll_id => @r2.id, :format => :json
      assigns(:status).should eq(404)
      assigns(:message).should eq("you haven't built me to do anything else yet...")
    end

  end
  
  describe "DELETE destroy" do
    it "destroys a roll successfuly" do
      frame = mock_model(Frame)
      Frame.stub!(:find).and_return(frame)
      frame.should_receive(:destroy).and_return(frame)
      delete :destroy, :frame_id => frame.id, :format => :json
      assigns(:status).should eq(200)
    end
    
    it "unsuccessfuly destroys a roll returning 404" do
      frame = mock_model(Frame)
      Frame.stub!(:find).and_return(frame)
      frame.should_receive(:destroy).and_return(false)
      delete :destroy, :frame_id => frame.id, :format => :json
      assigns(:status).should eq(404)
    end
  end
  
end