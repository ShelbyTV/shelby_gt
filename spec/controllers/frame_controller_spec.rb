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
    @frame.save
    Roll.stub(:find) { @roll }
    @roll.stub_chain(:frames, :sort) { [@frame] }
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
      get :show, :id => "whatever", :format => :json
      assigns(:status).should eq(404)
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
      GT::UserActionManager.should_not_receive(:view!)

      sign_out @u1

      post :watched, :frame_id => @frame.id, :start_time => "0", :end_time => "14", :format => :json
    end

    it "shouldn't need start and end times" do
      GT::UserActionManager.should_receive(:view!)
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
      #undo the stub above so this actually fails
      Frame.stub(:find) { nil }

      post :watched, :frame_id => "somebadid", :format => :json
      assigns(:status).should eq(404)
    end
  end

  describe "POST share" do
    before(:each) do
      sign_in @u1
      resp = {"awesm_urls" => [
        {"service"=>"twitter", "parent"=>nil, "original_url"=>"http://henrysztul.info", "redirect_url"=>"http://henrysztul.info?awesm=shl.by_4", "awesm_id"=>"shl.by_4", "awesm_url"=>"http://shl.by/4", "user_id"=>nil, "path"=>"4", "channel"=>"twitter", "domain"=>"shl.by"},
        {"service"=>"facebook", "parent"=>nil, "original_url"=>"http://henrysztul.info", "redirect_url"=>"http://henrysztul.info?awesm=shl.by_fb", "awesm_id"=>"shl.by_fb", "awesm_url"=>"http://shl.by/fb", "user_id"=>nil, "path"=>"fb", "channel"=>"facebook-post", "domain"=>"shl.by"}]}
      Awesm::Url.stub(:batch).and_return([200, resp])
    end

    context "frame on normal roll" do

      before(:each) do
        @roll = Factory.create(:roll, :creator => @u1)
        @frame = Factory.create(:frame, :roll => @roll, :conversation => Factory.create(:conversation))
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
        @u1.authentications << Authentication.new(:provider => "twitter")
        @u1.authentications << Authentication.new(:provider => "facebook")
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
      end

      it "should not post if the destination is not supported" do
        post :share, :frame_id => @frame.id.to_s, :destination => ["awesome_service"], :text => "testing", :format => :json
        assigns(:status).should eq(404)
      end

      it "should return 404 if a comment or destination is not present" do
        post :share, :frame_id => @frame.id.to_s, :destination => ["twitter"], :format => :json
        assigns(:status).should eq(404)

        post :share, :frame_id => @frame.id.to_s, :text => "testing", :format => :json
        assigns(:status).should eq(404)

        assigns(:message).should eq("a destination and text is required to post")
      end

      it "should return 404 if frame/roll not found" do
        Frame.stub!(:find).and_return(nil)
        post :share, :frame_id => "whatever", :destination => ["twitter"], :text => "testing", :format => :json
        assigns(:status).should eq(404)
      end

    end

    context "frame on watch later roll" do

      before(:each) do
        @roll.roll_type = Roll::TYPES[:special_watch_later]
      end

      it "should return 200 if frame is on watch later roll and has ancestors" do
        @frame_ancestor = Factory.create(:frame)
        @frame.stub!(:frame_ancestors).and_return [@frame_ancestor._id]
        Frame.should_receive(:find).twice.and_return(@frame, @frame_ancestor)
        post :share, :frame_id => @frame.id.to_s, :destination => ["twitter"], :text => "testing", :format => :json
        assigns(:status).should eq(200)
      end

      it "should return 404 if frame is on watch later roll and has no ancestors" do
        @frame.stub!(:frame_ancestors).and_return []
        Frame.should_receive(:find).once.and_return(@frame)
        post :share, :frame_id => @frame.id.to_s, :destination => ["twitter"], :text => "testing", :format => :json
        assigns(:status).should eq(404)
        assigns(:message).should eq("no valid frame to share")
      end

    end

    context "email share" do
      before(:each) do
        GT::SocialPoster.stub(:email_frame)
      end

      it "should try to save email addresses to user's autocomplete" do
        controller.current_user.should_receive(:store_autocomplete_info).once

        post :share, :frame_id => @frame.id.to_s, :destination => ["email"], :text => "testing", :addresses => "spinosa@gmail.com, invalidaddress, j@jay.net", :format => :json
      end

      it "should NOT try to save email addresses to user's autocomplete if none are specified" do
        controller.current_user.should_not_receive(:store_autocomplete_info)

        post :share, :frame_id => @frame.id.to_s, :destination => ["email"], :text => "testing", :format => :json
      end

      context "frame on watch later roll and has no ancestors" do
      before(:each) do
        @roll.roll_type = Roll::TYPES[:special_watch_later]
        @video = Factory.create(:video)
        @frame.video = @video
        @frame.stub!(:frame_ancestors).and_return []
        Frame.should_receive(:find).once.and_return(@frame)
      end

      it "should return 200" do
        post :share, :frame_id => @frame.id.to_s, :destination => ["email"], :text => "testing", :format => :json
        assigns(:status).should eq(200)
      end

      end

    end

  end

  describe "POST add_to_watch_later" do
    before(:each) do
      @f2 = Factory.create(:frame)
      @f2.video = Factory.create(:video)
      @f2.save
    end

    it "creates a like UserAction" do
      GT::UserActionManager.should_receive(:like!).with(@u1.id, @f2.id, @f2.video_id)

      post :add_to_watch_later, :frame_id => @f2.id, :format => :json
    end

    it "creates a new Frame" do
      Frame.should_receive(:get_ancestor_of_frame).and_return(nil)

      lambda {
        post :add_to_watch_later, :frame_id => @f2.id, :format => :json
      }.should change { Frame.count } .by 1

      assigns(:new_frame).persisted?.should == true
      assigns(:new_frame).frame_ancestors.include?(@f2.id).should == true
      assigns(:status).should eq(200)
    end
  end

  describe "POST like" do
    before(:each) do
      @f2 = Factory.create(:frame)
      @f2.video = Factory.create(:video)
      @f2.save
    end

    it "creates a like UserAction" do
      GT::UserActionManager.should_receive(:like!).with(@u1.id, @f2.id, @f2.video_id)

      post :like, :frame_id => @f2.id, :format => :json
    end

  end

  describe "POST create" do
    before(:each) do
      @video_url = CGI::escape("http://some.video.url.com/of_a_movie_i_like")
      @message_text = "boy this is awesome"
      @message = Factory.build(:message, :text => @message_text, :public => true, :nickname => @u1.nickname, :realname => @u1.name, :user_image_url => @u1.user_image)
      @video = Factory.create(:video, :source_url => @video_url)

      @f1 = Factory.create(:frame, :video => @video)
      @f1.roll = Factory.create(:roll)
      @f1.conversation = stub_model(Conversation)
      @f1.save

      @f2 = Factory.create(:frame)
      @f2.video = Factory.create(:video)
      @f2.roll = @r2 = Factory.create(:roll)
      @f2.save

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
        GT::UserActionManager.should_receive(:frame_rolled!)

        post :create, :roll_id => @r2.id, :url => @video_url, :text => @message_text, :source => "bookmarklet", :format => :json
        assigns(:status).should eq(200)
        assigns(:frame).should eq(@f1)
      end

      it "should process the new frame message for hashtags" do
        GT::Framer.stub(:create_frame).with(:creator => @u1, :roll => @r2, :video => @video, :message => @message, :action => DashboardEntry::ENTRY_TYPE[:new_bookmark_frame] ).and_return({:frame => @f1})
        GT::HashtagProcessor.should_receive(:process_frame_message_hashtags_for_channels).with(@f1)
        GT::UserActionManager.should_receive(:frame_rolled!)

        post :create, :roll_id => @r2.id, :url => @video_url, :text => @message_text, :source => "bookmarklet", :format => :json
      end

      it "should create a new frame if given video_url and text params" do
        GT::Framer.stub(:create_frame).with(:creator => @u1, :roll => @r2, :video => @video, :message => @message, :action => DashboardEntry::ENTRY_TYPE[:new_bookmark_frame] ).and_return({:frame => @f1})
        GT::UserActionManager.should_receive(:frame_rolled!)

        post :create, :roll_id => @r2.id, :url => @video_url, :text => @message_text, :format => :json
        assigns(:status).should eq(200)
        assigns(:frame).should eq(@f1)
      end

      it "should return a new frame if a video_url is given but a message is not" do
        GT::Framer.stub(:create_frame).and_return({:frame => @f1})
        GT::UserActionManager.should_receive(:frame_rolled!)

        post :create, :roll_id => @r2.id, :url => @video_url, :format => :json
        assigns(:status).should eq(200)
        assigns(:frame).should eq(@f1)
      end

      it "should be ok if action is f-d up" do
        GT::VideoManager.stub(:get_or_create_videos_for_url).with(@video_url).and_return({:videos=> [@video]})
        GT::Framer.stub(:create_frame_from_url).and_return({:frame => @f1})
        GT::UserActionManager.should_not_receive(:frame_rolled!)

        post :create, :roll_id => @r2.id, :url => @video_url, :source => "fucked_up", :format => :json
        assigns(:status).should eq(404)
      end

      it "should not create roll if its not the current_users roll" do
        GT::Framer.stub(:create_frame).and_return({:frame => @f1})
        new_roll = Factory.create(:roll, :creator => @u2 , :public => false )
        Roll.stub(:find) { new_roll }
        GT::UserActionManager.should_not_receive(:frame_rolled!)

        post :create, :roll_id => new_roll.id, :url => @video_url, :format => :json
        assigns(:status).should eq(403)
      end

      it "should handle bad roll_id" do
        Roll.stub(:find) { nil }
        GT::UserActionManager.should_not_receive(:frame_rolled!)
        post :create, :roll_id => "some_Roll_id_that_doesnt_exist", :url => @video_url, :format => :json
        assigns(:status).should eq(404)
      end

    end

    context "new frame by re rolling a frame" do
      it "should re_roll and returns one frame to @frame if given a frame_id param" do
        @f1.should_receive(:re_roll).and_return({:frame => @f2})
        GT::UserActionManager.should_receive(:frame_rolled!)

        post :create, :roll_id => @r2.id, :frame_id => @f1.id, :format => :json
        assigns(:status).should eq(200)
        assigns(:frame).should eq(@f2)
      end

      it "should process the new frame message for hashtags" do
        @f1.stub(:re_roll).and_return({:frame => @f2})
        GT::HashtagProcessor.should_receive(:process_frame_message_hashtags_for_channels).with(@f2)
        GT::UserActionManager.should_receive(:frame_rolled!)

        post :create, :roll_id => @r2.id, :frame_id => @f1.id, :format => :json
      end

      it "returns 403 if user cannot re_roll to that roll" do
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
    end

  end

  describe "DELETE destroy" do
    it "destroys a frame successfuly" do
      frame = Factory.create(:frame)
      Frame.stub!(:find).and_return(frame)
      frame.should_receive(:destroy).and_return(frame)
      delete :destroy, :id => frame.id, :format => :json
      assigns(:status).should eq(200)
    end

    it "unsuccessfuly destroys a frame returning 404" do
      frame = Factory.create(:frame)
      Frame.stub!(:find).and_return(frame)
      frame.should_receive(:destroy).and_return(false)
      delete :destroy, :id => frame.id, :format => :json
      assigns(:status).should eq(404)
    end
  end

  describe "GET short_link" do
    before(:each) do
      sign_in @u1
      resp = {"awesm_urls" => [
        {"service"=>"email", "parent"=>nil, "original_url"=>"http://henrysztul.info", "redirect_url"=>"http://henrysztul.info?awesm=shl.by_4", "awesm_id"=>"shl.by_4", "awesm_url"=>"http://shl.by/4", "user_id"=>nil, "path"=>"4", "channel"=>"email", "domain"=>"shl.by"}
      ]}
      Awesm::Url.stub(:batch).and_return([200, resp])
    end

    context "normal frame" do

      before(:each) do
        @frame = Factory.create(:frame, :roll => Factory.create(:roll, :creator => @u1), :conversation => Factory.create(:conversation))
        Frame.stub!(:find).and_return(@frame)
      end

      it "should return 200" do
        get :short_link, :frame_id => @frame.id.to_s, :format => :json
        assigns(:status).should eq(200)
      end

      it "should assign correct shortlink" do
        get :short_link, :frame_id => @frame.id.to_s, :format => :json
        assigns(:short_link).should eq({'email' => @frame.short_links[:email]})
      end

    end

    context "watch later roll frame" do

      context "with ancestors" do

        before(:each) do
          @roll = Factory.create(:roll, :roll_type => Roll::TYPES[:special_watch_later], :creator => @u1)
          @frame_ancestor = Factory.create(:frame)
          @frame = Factory.create(:frame, :roll => @roll, :conversation => Factory.create(:conversation))
          @frame.stub!(:frame_ancestors).and_return [@frame_ancestor._id]
          Frame.stub!(:find).and_return(@frame, @frame_ancestor)
        end

        it "should return 200" do
          get :short_link, :frame_id => @frame.id.to_s, :format => :json
          assigns(:status).should eq(200)
        end

        it "should assign frame's last ancestor's shortlink" do
          get :short_link, :frame_id => @frame.id.to_s, :format => :json
          assigns(:short_link).should eq({'email' => @frame_ancestor.short_links[:email]})
        end

      end

      context "with no ancestors" do

        before(:each) do
          @roll = Factory.create(:roll, :roll_type => Roll::TYPES[:special_watch_later], :creator => @u1)
          @video = Factory.create(:video)
          @frame = Factory.create(:frame, :roll => @roll, :video => @video, :conversation => Factory.create(:conversation))
          @frame.stub!(:frame_ancestors).and_return []
          Frame.stub!(:find).and_return(@frame)
        end

        it "should return 200" do
          get :short_link, :frame_id => @frame.id.to_s, :format => :json
          assigns(:status).should eq(200)
        end

        it "should assign frame's video's shortlink" do
          get :short_link, :frame_id => @frame.id.to_s, :format => :json
          assigns(:short_link).should eq({'email' => @video.short_links[:email]})
        end

      end

    end

    # it "should assign correct shortlink for a normal frame" do
    #   get :short_link, :frame_id => @frame.id.to_s, :format => :json
    #   assigns(:short_link).should eq(@frame.short_links['email'])
    # end

    # it "should assign video shortlink for a frame on the queue" do
    #   get :short_link, :frame_id => @frame.id.to_s, :format => :json
    #   assigns(:short_link).should eq(@frame.short_links['email'])
    # end

    it "returns 404 when cant find frame" do
      Frame.stub(:find) { nil }
      get :short_link, :frame_id => @frame.id.to_s, :format => :json
      assigns(:status).should eq(404)
      assigns(:message).should eq("could not find frame")
    end

    it "returns 404 when no valid entity to shortlink" do
      @frame = Factory.create(:frame)
      Frame.stub!(:find).and_return(@frame)
      controller.stub!(:get_linkable_entity).and_return(nil)
      get :short_link, :frame_id => @frame.id.to_s, :format => :json
      assigns(:status).should eq(404)
      assigns(:message).should eq("no valid entity to shortlink")
    end

  end

end
