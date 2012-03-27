require 'spec_helper'

require 'predator_manager'

# UNIT test
describe GT::PredatorManager do
  before(:each) do
    Settings::Beanstalk[:available] = true
    @bean_conn = mock_model("BeanConn")
    Beanstalk::Connection.stub(:new).and_return(@bean_conn)
  end
  
  context "initialize_video_processing" do
    it "should backfill and add to stream for twitter" do
      fauth = mock_model("FAuth", :provider => 'twitter', :uid => "userid", :oauth_token => "oatoken", :oauth_secret => "oasecret")
      
      @bean_conn.should_receive(:use).with(Settings::Beanstalk.tubes['twitter_backfill'])
      @bean_conn.should_receive(:put).with("{\"action\":\"add_user\",\"twitter_id\":\"userid\",\"oauth_token\":\"oatoken\",\"oauth_secret\":\"oasecret\"}")
      
      @bean_conn.should_receive(:use).with(Settings::Beanstalk.tubes['twitter_add_stream'])
      @bean_conn.should_receive(:put).with("{\"action\":\"add_user\",\"twitter_id\":\"userid\"}")
      
      GT::PredatorManager.initialize_video_processing(nil, fauth)
    end
    
    it "should add user to facebook poller" do
      fauth = mock_model("FAuth", :provider => 'facebook', :uid => "userid", :oauth_token => "oatoken")
      
      @bean_conn.should_receive(:use).with(Settings::Beanstalk.tubes['facebook_add_user'])
      @bean_conn.should_receive(:put).with("{\"fb_id\":\"userid\",\"fb_access_token\":\"oatoken\"}")
      
      GT::PredatorManager.initialize_video_processing(nil, fauth)
    end
    
    it "should add user to tumblr poller" do
      fauth = mock_model("FAuth", :provider => 'tumblr', :uid => "userid", :oauth_token => "oatoken", :oauth_secret => "oasecret")
      
      @bean_conn.should_receive(:use).with(Settings::Beanstalk.tubes['tumblr_add_user'])
      @bean_conn.should_receive(:put).with("{\"tumblr_id\":\"userid\",\"oauth_token\":\"oatoken\",\"oauth_secret\":\"oasecret\"}")
      
      GT::PredatorManager.initialize_video_processing(nil, fauth)
    end
  end
  
  context "update_video_processing" do
    it "should do nothing on twitter" do
      @bean_conn.should_not_receive(:use)
      GT::PredatorManager.update_video_processing(nil, mock_model("FAuth", :provider => 'twitter'))
    end
    
    it "should add user to facebook poller like normals" do
      fauth = mock_model("FAuth", :provider => 'facebook', :uid => "userid", :oauth_token => "oatoken")
      
      @bean_conn.should_receive(:use).with(Settings::Beanstalk.tubes['facebook_add_user'])
      @bean_conn.should_receive(:put).with("{\"fb_id\":\"userid\",\"fb_access_token\":\"oatoken\"}")
      
      GT::PredatorManager.update_video_processing(nil, fauth)
    end
    
    it "should do nothing on tumblr" do
      @bean_conn.should_not_receive(:use)
      GT::PredatorManager.update_video_processing(nil, mock_model("FAuth", :provider => 'tumblr'))
    end
  end
end