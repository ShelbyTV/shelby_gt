require 'spec_helper'
require 'rack/oauth2/server'
describe V1::VideoController do
  describe "GET show" do
    it "assigns a video to @video" do
      @video = Factory.create(:video, :title=>"test title")
      Video.stub(:find) { @video }
      get :show, {:id => @video.id, :format => :json}, :authorization=>"OAuth 302f117112f6cb8e8b1473b20cf06f65ce40f888807466ff40281d24d30cd8ca"
      assigns(:video).should eq(@video)
      assigns(:status).should eq(200)
    end

    it "returns 404 if cant find @video" do
      @video = stub_model(Video)
      Video.stub(:find) { nil }
      get :show, :id => @video.id, :format => :json
      assigns(:status).should eq(404)
    end

  end

  describe "PUT watched" do
    before(:each) do
      @video = Factory.create(:video)
      Video.stub(:find) { @video }
    end

    it "should return 200 if Video is found" do
      put :watched, :video_id => @video.id, :format => :json
      assigns(:video).should eq(@video)
      assigns(:status).should eq(200)
    end

    it "should return 404 if Video can't be found" do
      #undo the stub above so this actually fails
      Video.stub(:find) { nil }
      @video.should_not_receive(:view!)
      @video.should_not_receive(:reload)

      put :watched, :video_id => "somebadid", :format => :json
      assigns(:status).should eq(404)
    end

    context "signed in" do
      before(:each) do
        @u1 = Factory.create(:user)
        @u1.upvoted_roll = Factory.create(:roll, :creator => @u1)
        @u1.watch_later_roll = Factory.create(:roll, :creator => @u1)
        @u1.viewed_roll = Factory.create(:roll, :creator => @u1)
        @u1.save
        sign_in @u1
      end

      it "should call view! on the video" do
        @video.should_receive(:view!).with(@u1)
        @video.should_receive(:reload)

        put :watched, :video_id => @video.id, :format => :json
      end
    end

    it "shouldn't need a logged in user" do
      @video.should_receive(:view!).with(nil)
      @video.should_receive(:reload)

      put :watched, :video_id => @video.id, :start_time => "0", :end_time => "14", :format => :json
    end

  end

  describe "GET search" do
    it "should return 404 if a query not given" do
      get :search, :provider => "vimeo", :format => :json
      assigns(:status).should eq(404)
    end

    it "should accept a valid provider" do
      get :search, :q => "test", :provider => "vimeo", :format => :json
      assigns(:status).should eq(200)
    end

    it "should not accept an invalid provider" do
      get :search, :q => "test", :provider => "blah", :format => :json
      assigns(:status).should eq(404)
    end

    it "should return successfully if alls well that ends well" do
      get :search, :q => "test", :provider => "vimeo", :format => :json
      assigns(:status).should eq(200)
    end

  end

  describe "PUT unplayable" do
    before(:each) do
      @u1 = Factory.create(:user)
      sign_in @u1
      @video = Factory.create(:video, :title=>"test title")
      Video.stub(:find) { @video }
    end

    it "updates first_unplayable_at when it's nil" do
      @video.first_unplayable_at.should be_nil
      @video.first_unplayable_at.should be_nil

      put :unplayable, {:video_id => @video.id, :format => :json}

      assigns(:video).should eq(@video)
      @video.first_unplayable_at.should_not be_nil
      @video.last_unplayable_at.should_not be_nil
    end

    it "doesn't update first_unplayable_at when it's not nil" do
      t = @video.first_unplayable_at = 1.hour.ago
      @video.save

      put :unplayable, {:video_id => @video.id, :format => :json}

      assigns(:video).should eq(@video)
      @video.first_unplayable_at.to_i.should == t.to_i
      @video.last_unplayable_at.should_not be_nil
    end

  end

  describe "PUT fix_if_necessary" do
    before(:each) do
      @u1 = Factory.create(:user)
      sign_in @u1
      @video = Factory.create(:video, :title=>"test title")
      Video.stub(:find) { @video }
    end

    it "returns the same video" do
      GT::VideoManager.should_receive(:fix_video_if_necessary).with(@video).and_return(@video)

      put :fix_if_necessary, {:video_id => @video.id, :format => :json}

      assigns(:video).should eq(@video)
    end
  end

end
