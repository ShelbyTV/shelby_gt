require 'spec_helper'

require 'job_processor'
require 'bean_job'

# UNIT test
describe GT::Arnold::JobProcessor do
  before(:each) do
    @fake_job = mock_model("MJob", :jobid => "fake")
    @user = User.new
  end
  
  it "should return :bad_job if job cannot be parsed" do
    GT::Arnold::BeanJob.stub(:parse_job).and_return(false)
    GT::Arnold::JobProcessor.process_job(@fake_job, :fibers, :max_fibers).should == :bad_job
  end
  
  it "should return :no_videos if there are no vids at that url" do
    GT::Arnold::BeanJob.stub(:parse_job).and_return({:url => "bad://url"})
    GT::VideoManager.stub(:get_or_create_videos_for_url).and_return([])
    GT::Arnold::JobProcessor.process_job(@fake_job, :fibers, :max_fibers).should == :no_videos
  end
  
  it "should return :no_social_message if there is no tweet, fb, or tumblr social post" do
    GT::Arnold::BeanJob.stub(:parse_job).and_return({:url => "bad://url"})
    GT::VideoManager.stub(:get_or_create_videos_for_url).and_return([{:fake => true}])
    GT::Arnold::JobProcessor.process_job(@fake_job, :fibers, :max_fibers).should == :no_social_message
  end
  
  it "should return :no_observing_user if there a user could not be found" do
    GT::Arnold::BeanJob.stub(:parse_job).and_return({:url => "bad://url", :twitter_status_update => "whatever", :provider_type => 'pt', :provider_user_id => 'puid'})
    GT::VideoManager.stub(:get_or_create_videos_for_url).and_return([{:fake => true}])
    GT::TwitterNormalizer.stub(:normalize_tweet).with("whatever").and_return(true)
    
    # fail to find user...
    User.stub(:find_by_provider_name_and_id).with('pt', 'puid').once.and_return(nil)
    
    GT::Arnold::JobProcessor.process_job(@fake_job, mock_model("FFiber", :delete => true, :size => 1), :max_fibers).should == :no_observing_user
  end
  
  it "should get the correct observing user from job_details" do
    GT::Arnold::BeanJob.stub(:parse_job).and_return({:url => "bad://url", :twitter_status_update => "whatever", :provider_type => 'pt', :provider_user_id => 'puid'})
    GT::VideoManager.stub(:get_or_create_videos_for_url).and_return([{:fake => true}])
    GT::TwitterNormalizer.stub(:normalize_tweet).with("whatever").and_return(true)
    
    # make sure we try to find user w/ correct details
    User.stub(:find_by_provider_name_and_id).with('pt', 'puid').once.and_return(@user)
    
    GT::SocialSorter.stub(:sort).and_return(:sorted)
    GT::Arnold::JobProcessor.process_job(@fake_job, mock_model("FFiber", :delete => true, :size => 1), :max_fibers).should == [:sorted]
  end
  
  it "should SocialSort multiple videos" do
    GT::Arnold::BeanJob.stub(:parse_job).and_return({:url => "bad://url", :twitter_status_update => "whatever", :provider_type => 'pt', :provider_user_id => 'puid'})
    GT::VideoManager.stub(:get_or_create_videos_for_url).and_return([{:fake => 1}, {:fake => 2}])
    GT::TwitterNormalizer.stub(:normalize_tweet).with("whatever").and_return(true)
    User.stub(:find_by_provider_name_and_id).with('pt', 'puid').and_return(@user)
    GT::SocialSorter.stub(:sort).and_return(:sorted)
    GT::Arnold::JobProcessor.process_job(@fake_job, mock_model("FFiber", :delete => true, :size => 1), :max_fibers).should == [:sorted, :sorted]
  end
  
  it "should remove it's controlling fiber from fibers array"  do
    GT::Arnold::BeanJob.stub(:parse_job).and_return({:url => "bad://url", :twitter_status_update => "whatever", :provider_type => 'pt', :provider_user_id => 'puid'})
    GT::VideoManager.stub(:get_or_create_videos_for_url).and_return([{:fake => true}])
    GT::TwitterNormalizer.stub(:normalize_tweet).with("whatever").and_return(true)
    User.stub(:find_by_provider_name_and_id).with('pt', 'puid').and_return(@user)
    GT::SocialSorter.stub(:sort).and_return(:sorted)
    
    #make sure delete is called exactly once
    mock_fiber = mock_model("FFiber", :size => 1)
    mock_fiber.stub(:delete).once.and_return(true)
    
    GT::Arnold::JobProcessor.process_job(@fake_job, mock_fiber, :max_fibers).should == [:sorted]
  end
  
end