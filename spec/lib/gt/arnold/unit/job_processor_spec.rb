require 'spec_helper'

require 'job_processor'
require 'bean_job'
require 'memcached_manager'

# UNIT test
describe GT::Arnold::JobProcessor do

  $cache = [[""] * 10, 0]
  before(:each) do
    @fake_job = [mock_model("MJob", :jobid => "fake")]
    @user = User.new

    @badurl = "bad://url"
    @urlb = "bad://b"
    @urlc = "bad://c"

    
    #make sure delete is *always* called exactly once
    @mock_fibers = mock_model("FFiber", :size => 1)
    @mock_fibers.should_receive(:delete)


    
    GT::Arnold::MemcachedManager.stub(:get_client).and_return(nil)
  end
  
  it "should return :bad_job if job cannot be parsed" do
    GT::Arnold::BeanJob.stub(:parse_job).and_return(false)
    GT::Arnold::JobProcessor.process_job(@fake_job, @mock_fibers, :max_fibers).should == [:bad_job]
  end
  
  it "should return :no_videos if there are no vids at :url" do
    GT::Arnold::BeanJob.stub(:parse_job).and_return({:url => @badurl})
    GT::VideoManager.stub(:get_or_create_videos_for_url).and_return([])
    GT::Arnold::JobProcessor.process_job(@fake_job, @mock_fibers, :max_fibers, $cache, false).should == [:no_videos]
  end

  it "should sleep for a few seconds" do
    GT::Arnold::BeanJob.stub(:parse_job).and_return({:url => @badurl})
    GT::VideoManager.stub(:get_or_create_videos_for_url).and_return([])
    beforeTime = Time.now
    GT::Arnold::JobProcessor.process_job(@fake_job, @mock_fibers, :max_fibers, $cache, false).should == [:no_videos]
    (Time.now - beforeTime).should > 1
    $cache[0][0].should == @badurl
    $cache[1] .should == 1
  end

  it "shouldn't sleep" do
    @mock_fibers.should_receive(:delete)
    GT::Arnold::BeanJob.stub(:parse_job).and_return({:url => @urlb})
    GT::Arnold::BeanJob.stub(:parse_job).and_return({:url => @urlb})
    GT::VideoManager.stub(:get_or_create_videos_for_url).and_return([])
    beforeTime = Time.now
    GT::Arnold::JobProcessor.process_job([@fake_job, @fake_job], @mock_fibers, :max_fibers, $cache, false).should == [:no_videos, :no_videos]
    (Time.now - beforeTime).should < 1
    $cache[0][0].should == @badurl
    $cache[1].should == 2
  end

  
  it "should return :no_videos if there are no vids at :expanded_urls" do
    GT::Arnold::BeanJob.stub(:parse_job).and_return({:expanded_urls => ["bad://url1", "bad://url2"]})
    GT::VideoManager.stub(:get_or_create_videos_for_url).and_return([])
    GT::Arnold::JobProcessor.process_job(@fake_job, @mock_fibers, :max_fibers).should == [:no_videos]
  end
  
  it "should return :no_social_message if there is no tweet, fb, or tumblr social post" do
    GT::Arnold::BeanJob.stub(:parse_job).and_return({:url => "bad://url"})
    GT::VideoManager.stub(:get_or_create_videos_for_url).and_return([{:fake => true}])
    GT::Arnold::JobProcessor.process_job(@fake_job, @mock_fibers, :max_fibers).should == [:no_social_message]
  end
  
  it "should return :no_observing_user if there a user could not be found" do
    GT::Arnold::BeanJob.stub(:parse_job).and_return({:url => "bad://url", :twitter_status_update => "whatever", :provider_type => 'pt', :provider_user_id => 'puid'})
    GT::VideoManager.stub(:get_or_create_videos_for_url).and_return([{:fake => true}])
    GT::TwitterNormalizer.stub(:normalize_tweet).with("whatever").and_return(mock_model(Message, :nickname => "nick"))
    
    # fail to find user...
    User.stub(:find_by_provider_name_and_id).with('pt', 'puid').once.and_return(nil)
    
    GT::Arnold::JobProcessor.process_job(@fake_job, @mock_fibers, :max_fibers).should == [:no_observing_user]
  end
  
  it "should get the correct observing user from job_details" do
    GT::Arnold::BeanJob.stub(:parse_job).and_return({:url => "bad://url", :twitter_status_update => "whatever", :provider_type => 'pt', :provider_user_id => 'puid'})
    GT::VideoManager.stub(:get_or_create_videos_for_url).and_return([{:fake => true}])
    GT::TwitterNormalizer.stub(:normalize_tweet).with("whatever").and_return(mock_model(Message, :nickname => "nick"))
    
    # make sure we try to find user w/ correct details
    User.stub(:find_by_provider_name_and_id).with('pt', 'puid').once.and_return(@user)
    
    GT::SocialSorter.stub(:sort).and_return(:sorted)
    GT::Arnold::JobProcessor.process_job(@fake_job, @mock_fibers, :max_fibers).should == [[:sorted]]
  end
  
  it "should SocialSort multiple videos from :url" do
    GT::Arnold::BeanJob.stub(:parse_job).and_return({:url => "ok://url", :twitter_status_update => "whatever", :provider_type => 'pt', :provider_user_id => 'puid'})
    GT::VideoManager.stub(:get_or_create_videos_for_url).and_return([[{:fake => 1}, {:fake => 2}], false])
    GT::TwitterNormalizer.stub(:normalize_tweet).with("whatever").and_return(mock_model(Message, :nickname => "nick"))
    User.stub(:find_by_provider_name_and_id).with('pt', 'puid').and_return(@user)
    GT::SocialSorter.stub(:sort).and_return(:sorted)
    
    # 1 standard url returning 2 videos...
    GT::Arnold::JobProcessor.process_job(@fake_job, @mock_fibers, :max_fibers).should == [[:sorted, :sorted]]
  end
  
  it "should SocialSort multiple videos from :expanded_urls" do
    GT::Arnold::BeanJob.stub(:parse_job).and_return({:expanded_urls => ["ok://url1", "ok://url2"], :twitter_status_update => "whatever", :provider_type => 'pt', :provider_user_id => 'puid'})
    GT::VideoManager.stub(:get_or_create_videos_for_url).and_return([[{:fake => 1}, {:fake => 2}], false])
    GT::TwitterNormalizer.stub(:normalize_tweet).with("whatever").and_return(mock_model(Message, :nickname => "nick"))
    User.stub(:find_by_provider_name_and_id).with('pt', 'puid').and_return(@user)
    GT::SocialSorter.stub(:sort).and_return(:sorted)
    
    # 2 expanded urls returning 2 videos each...
    GT::Arnold::JobProcessor.process_job(@fake_job, @mock_fibers, :max_fibers).should == [[:sorted, :sorted, :sorted, :sorted]]
  end
  
  it "should remove it's controlling fiber from fibers array"  do
    GT::Arnold::BeanJob.stub(:parse_job).and_return({:url => "ok://url", :twitter_status_update => "whatever", :provider_type => 'pt', :provider_user_id => 'puid'})
    GT::VideoManager.stub(:get_or_create_videos_for_url).and_return([{:fake => true}])
    GT::TwitterNormalizer.stub(:normalize_tweet).with("whatever").and_return(mock_model(Message, :nickname => "nick"))
    User.stub(:find_by_provider_name_and_id).with('pt', 'puid').and_return(@user)
    GT::SocialSorter.stub(:sort).and_return(:sorted)
    
    # see before(:each) for the @mock_fiber that expects to be deleted
    
    GT::Arnold::JobProcessor.process_job(@fake_job, @mock_fibers, :max_fibers).should == [[:sorted]]
  end
  
end
