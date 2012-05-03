require 'spec_helper'

describe V1::VideoController do
  describe "GET show" do
    it "assigns a video to @video" do
      @video = Factory.create(:video, :title=>"test title")
      Video.stub(:find) { @video }
      get :show, :id => @video.id, :format => :json
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

end