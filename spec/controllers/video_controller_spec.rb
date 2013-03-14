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
