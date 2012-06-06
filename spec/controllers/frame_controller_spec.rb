require 'spec_helper'
require 'video_manager'
require 'message_manager'
require 'link_shortener'

describe V1::FrameController do
  before(:each) do
    @u1 = Factory.create(:user)
    @u1.upvoted_roll = Factory.create(:roll, :creator => @u1)
    @u1.watch_later_roll = Factory.create(:roll, :creator => @u1)
    @u1.viewed_roll = Factory.create(:roll, :creator => @u1)
    @u1.save
    sign_in @u1
    @u2 = Factory.create(:user)
    @roll = Factory.create(:roll, :creator => @u1)
    @frame = Factory.create(:frame)
    @frame.roll = @roll
    Roll.stub(:find) { @roll }
    Frame.stub(:find) { @frame }
    @roll.stub_chain(:frames, :sort) { [@frame] }
  end  

  describe "GET index" do
    it "assigns all frames in a roll to @frames" do
      Frame.stub_chain(:sort, :limit, :skip, :where, :all).and_return([@frame])
      get :index, :roll_id => @roll.id, :format => :json
      
      assigns(:roll).should eq(@roll)
      assigns(:frames).should eq([@frame])
      assigns(:status).should eq(200)
    end
    
    it "properly aliases for users public roll" do
      User.stub(:find) { @u1 }
      @u1.stub(:public_roll) { @roll }
      Frame.stub_chain(:sort, :limit, :skip, :where, :all).and_return([@frame])
      get :index, :user_id => @u1.id, :public_roll => true, :format => :json
      
      assigns(:roll).should eq(@roll)
      assigns(:frames).should eq([@frame])
      assigns(:status).should eq(200)
    end

    it "properly aliases for users heart roll" do
      User.stub(:find) { @u1 }
      @u1.stub(:upvoted_roll) { @roll }
      Frame.stub_chain(:sort, :limit, :skip, :where, :all).and_return([@frame])
      get :index, :user_id => @u1.id, :heart_roll => true, :format => :json
      
      assigns(:roll).should eq(@roll)
      assigns(:frames).should eq([@frame])
      assigns(:status).should eq(200)
    end

    it "should return error if user isnt logged in and roll is private" do
      sign_out @u1
      @roll.public = false; @roll.save
      Frame.stub_chain(:sort, :limit, :skip, :where, :all).and_return([@frame])
      get :index, :format => :json
      assigns(:status).should eq(404)
    end
    
    it "should return error if current user cant view roll" do
      @roll.creator = Factory.create(:user); @roll.public = false; @roll.save
      Frame.stub_chain(:sort, :limit, :skip, :where, :all).and_return([@frame])
      get :index, :format => :json
      assigns(:status).should eq(404)
    end
    
    it "should allow you to get frame for public roll w/o being signed in" do
      sign_out @u1
      
      Frame.stub_chain(:sort, :limit, :skip, :where, :all).and_return([@frame])
      get :index, :roll_id => @roll.id, :format => :json
      assigns(:roll).should eq(@roll)
      assigns(:frames).should eq([@frame])
      assigns(:status).should eq(200)
    end
    
    it "should not allow you to get frame for non-public roll w/o being signed in" do
      @roll.public = false
      sign_out @u1
      
      Frame.stub_chain(:sort, :limit, :skip, :where, :all).and_return([@frame])
      get :index, :format => :json
      assigns(:status).should eq(404)
    end
    
    it "returns 404 if cant find roll" do
      Roll.stub(:find) { nil }
      get :index, :format => :json
      assigns(:status).should eq(404)
      assigns(:message).should eq("could not find that roll")
    end
    
    it "should properly render frames if a since_id is included" do
      f1 = Factory.create(:frame)
      f2 = Factory.create(:frame)
      f3 = Factory.create(:frame)
      Frame.stub_chain(:sort, :limit, :skip, :where, :all).and_return([f2, f3])
      get :index, :roll_id => @roll.id, :since_id => f2.id.to_s,:format => :json
      assigns(:roll).should eq(@roll)
      assigns(:frames).should eq([f2,f3])
      assigns(:status).should eq(200)
    end
    
  end
  
  describe "GET show" do
    it "assigns one frame to @frame" do
      get :show, :id => @frame.id, :format => :json
      assigns(:status).should eq(200)
      assigns(:frame).should eq(@frame)
    end
    
    it "should allow non logged in user to see frame is roll is public" do
      sign_out @u1
      
      get :show, :id => @frame.id, :format => :json
      assigns(:status).should eq(200)
      assigns(:frame).should eq(@frame)
    end
    
    it "should not allow non logged in user to see frame if roll is not public" do
      @roll.public = false
      sign_out @u1
      
      get :show, :id => @frame.id, :format => :json
      assigns(:status).should eq(404)
    end
    
    it "should allow non logged in user to see frame if it's not on a roll" do
      @frame.roll_id = nil
      @frame.save
      sign_out @u1
      
      get :show, :id => @frame.id, :format => :json
      assigns(:status).should eq(200)
    end
    
    it "returns 404 when cant find frame" do
      Frame.stub(:find) { nil }
      get :show, :format => :json
      assigns(:status).should eq(404)
      assigns(:message).should eq("must supply an id")
    end
  end
  
  describe "POST upvote" do
    it "upvotes a frame successfuly" do
      @frame = Factory.create(:frame)
      @frame.should_receive(:upvote!).with(@u1).and_return(@frame)
      @frame.should_receive(:reload).and_return(@frame)
      
      lambda {
        post :upvote, :frame_id => @frame.id, :format => :json
      }.should change { UserAction.count } .by 1
      
      assigns(:status).should eq(200)
      assigns(:frame).should eq(@frame)
    end
    
    it "un-upvotes a frame successfuly" do
      @frame = Factory.create(:frame)
      @frame.should_receive(:upvote_undo!).with(@u1).and_return(@frame)
      @frame.should_receive(:reload).and_return(@frame)
      
      lambda {
        post :upvote, :frame_id => @frame.id, :undo => "1", :format => :json
      }.should change { UserAction.count } .by 1
      
      assigns(:status).should eq(200)
      assigns(:frame).should eq(@frame)
    end
    
    it "upvotes a frame UNsuccessfuly gracefully" do
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
      post :watched, :frame_id => "somebadid", :format => :json
      assigns(:status).should eq(404)
    end
  end
  
  describe "POST share" do
    before(:each) do
      sign_in @u1
      @frame = Factory.create(:frame, :roll => Factory.create(:roll, :creator => @u1))
      Frame.stub!(:find).and_return(@frame)
      resp = {"awesm_urls" => [
        {"service"=>"twitter", "parent"=>nil, "original_url"=>"http://henrysztul.info", "redirect_url"=>"http://henrysztul.info?awesm=shl.by_4", "awesm_id"=>"shl.by_4", "awesm_url"=>"http://shl.by/4", "user_id"=>nil, "path"=>"4", "channel"=>"twitter", "domain"=>"shl.by"},
        {"service"=>"facebook", "parent"=>nil, "original_url"=>"http://henrysztul.info", "redirect_url"=>"http://henrysztul.info?awesm=shl.by_fb", "awesm_id"=>"shl.by_fb", "awesm_url"=>"http://shl.by/fb", "user_id"=>nil, "path"=>"fb", "channel"=>"facebook-post", "domain"=>"shl.by"}]}
      Awesm::Url.stub(:batch).and_return([200, resp])
    end
    
    it "should return 200 if the user posts succesfully to destination" do
      post :share, :frame_id => @frame.id.to_s, :destination => ["twitter"], :text => "testing", :format => :json
      assigns(:status).should eq(200)      
    end
    
    it "should only add link text to each individual service's post" do
      GT::SocialPoster.should_receive(:post_to_twitter).with(@u1, "testing http://shl.by/4")
      GT::SocialPoster.should_receive(:post_to_facebook).with(@u1, "testing http://shl.by/fb", @frame)
      post :share, :frame_id => @frame.id.to_s, :destination => ["twitter", "facebook"], :text => "testing", :format => :json
    end
    
    it "should return 404 if destination is not an array" do
      post :share, :frame_id => @frame.id.to_s, :destination => "twitter", :text => "testing", :format => :json
      assigns(:status).should eq(404)
    end
    
    it "should return 404 if the user cant post to the destination" do
      post :share, :frame_id => @frame.id.to_s, :destination => ["facebook"], :text => "testing", :format => :json
      assigns(:status).should eq(404)
      assigns(:message).should eq("that user cant post to that destination")      
    end
    
    it "should not post if the destination is not supported" do
      post :share, :frame_id => @frame.id.to_s, :destination => ["awesome_service"], :text => "testing", :format => :json
      assigns(:status).should eq(404)
      assigns(:message).should eq("we dont support that destination yet :(")
    end
    
    it "should return 404 if a comment or destination is not present" do
      post :share, :frame_id => @frame.id.to_s, :destination => ["twitter"], :format => :json
      assigns(:status).should eq(404)
      
      post :share, :frame_id => @frame.id.to_s, :text => "testing", :format => :json
      assigns(:status).should eq(404)
      
      assigns(:message).should eq("a destination and text is required to post")
    end
        
    it "should return 404 if roll not found" do
      Frame.stub!(:find).and_return(nil)
      post :share, :destination => ["twitter"], :text => "testing", :format => :json
      assigns(:status).should eq(404)
      assigns(:message).should eq("could not find that frame")
    end
    
  end
  
  describe "POST add_to_watch_later" do
    before(:each) do    
      @f2 = Factory.create(:frame)
    end
    
    it "creates a UserAction" do
      GT::UserActionManager.should_receive(:watch_later!)
      Frame.should_receive(:get_ancestor_of_frame).and_return(nil)
      
      post :add_to_watch_later, :frame_id => @f2.id, :format => :json
    end
    
    it "creates a new Frame" do
      GT::UserActionManager.should_receive(:watch_later!)
      Frame.should_receive(:get_ancestor_of_frame).and_return(nil)
      
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
      @message_text = "boy this is awesome"
      @message = Factory.build(:message, :text => @message_text, :public => true, :nickname => @u1.nickname, :realname => @u1.name, :user_image_url => @u1.user_image)
      @video = Factory.create(:video, :source_url => @video_url)
      
      @f1 = Factory.create(:frame, :video => @video)
      @f1.conversation = stub_model(Conversation)

      @r2 = stub_model(Roll)
      @f2 = Factory.create(:frame)

      Frame.stub(:find) { @f1 }
      Roll.stub(:find) { @r2 }
    end
    
    context 'creating new frames from urls' do
      before(:each) do
        GT::VideoManager.stub(:get_or_create_videos_for_url).with(@video_url).and_return({:videos =>[@video]})
        GT::MessageManager.stub(:build_message).and_return(@message)        
      end
      
      it "should create a new frame if given valid source, video_url and text params" do
        GT::Framer.stub(:create_frame).with(:creator => @u1, :roll => @r2, :video => @video, :message => @message, :action => DashboardEntry::ENTRY_TYPE[:new_bookmark_frame] ).and_return({:frame => @f1})
      
        post :create, :roll_id => @r2.id, :url => @video_url, :text => @message, :source => "bookmark", :format => :json
        assigns(:status).should eq(200)
        assigns(:frame).should eq(@f1)
      end
    
      it "should create a new frame if given video_url and text params" do
        GT::Framer.stub(:create_frame).with(:creator => @u1, :roll => @r2, :video => @video, :message => @message, :action => DashboardEntry::ENTRY_TYPE[:new_bookmark_frame] ).and_return({:frame => @f1})
      
        post :create, :roll_id => @r2.id, :url => @video_url, :text => @message, :format => :json
        assigns(:status).should eq(200)
        assigns(:frame).should eq(@f1)
      end
    
      it "should return a new frame if a video_url is given but a message is not" do
        GT::Framer.stub(:create_frame).and_return({:frame => @f1})

        post :create, :roll_id => @r2.id, :url => @video_url, :format => :json
        assigns(:status).should eq(200)
        assigns(:frame).should eq(@f1)
      end
    
      it "should be ok if action is f-d up" do
        GT::VideoManager.stub(:get_or_create_videos_for_url).with(@video_url).and_return({:videos=> [@video]})
        GT::Framer.stub(:create_frame_from_url).and_return({:frame => @f1})
        post :create, :roll_id => @r2.id, :url => @video_url, :source => "fucked_up", :format => :json
        assigns(:status).should eq(404)
      end
      
      it "should not create roll if its not the current_users roll" do
        GT::Framer.stub(:create_frame).and_return({:frame => @f1})
        new_roll = Factory.create(:roll, :creator => @u2 , :public => false )
        Roll.stub(:find) { new_roll }
        
        post :create, :roll_id => new_roll.id, :url => @video_url, :format => :json
        assigns(:status).should eq(403)
      end
      
    end
    
    context "new frame by re rolling a frame" do
      it "should re_roll and returns one frame to @frame if given a frame_id param" do
        @f1.should_receive(:re_roll).and_return({:frame => @f2})

        post :create, :roll_id => @r2.id, :frame_id => @f1.id, :format => :json
        assigns(:status).should eq(200)
        assigns(:frame).should eq(@f2)
      end
      
      it "returns 403 if user can re_roll to that roll" do
        r = stub_model(Roll, :public => false)
        Roll.stub(:find) { r }
        
        u = Factory.create(:user)
        sign_in u
        
        post :create, :roll_id => r.id, :frame_id => @f1.id, :format => :json
        assigns(:status).should eq(403)
        assigns(:message).should eq("that user cant post to that roll")
      end
      
      it "returns 404 if it can't re_roll" do
        @f1.stub(:re_roll).and_raise(ArgumentError)

        post :create, :roll_id => @r2.id, :frame_id => @f1.id, :format => :json
        assigns(:status).should eq(404)
        assigns(:message).should eq("could not re_roll: ArgumentError")
      end
    end


    it "returns 404 if it theres no frame_id to re_roll or no video_url to make into a frame" do
      post :create, :roll_id => @r2.id, :format => :json
      assigns(:status).should eq(404)
      assigns(:message).should eq("you haven't built me to do anything else yet...")
    end

  end
  
  describe "DELETE destroy" do
    it "destroys a roll successfuly" do
      frame = Factory.create(:frame)
      Frame.stub!(:find).and_return(frame)
      frame.should_receive(:destroy).and_return(frame)
      delete :destroy, :id => frame.id, :format => :json
      assigns(:status).should eq(200)
    end
    
    it "unsuccessfuly destroys a roll returning 404" do
      frame = Factory.create(:frame)
      Frame.stub!(:find).and_return(frame)
      frame.should_receive(:destroy).and_return(false)
      delete :destroy, :id => frame.id, :format => :json
      assigns(:status).should eq(404)
    end
  end
  
end