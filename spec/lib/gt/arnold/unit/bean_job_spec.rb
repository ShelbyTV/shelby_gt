require 'spec_helper'

require 'bean_job'

# UNIT test
describe GT::Arnold::BeanJob do
  
  context "get_and_delete_job" do
    it "should reserve and delete a job, then return it" do
      GT::Arnold::BeanJob.stub(:bean).and_return(mock_model("BeanConexion", :reserve => :job, :delete => true))
      GT::Arnold::BeanJob.get_and_delete_job.should == :job
    end
  
    it "should return nil on Beanstalk::TimedOut" do
      GT::Arnold::BeanJob.stub(:bean).and_return(mock_model("BeanConexion").stub(:reserve).and_throw(Beanstalk::TimedOut))
      GT::Arnold::BeanJob.get_and_delete_job.should == nil
    end
    
    it "should reset bean and return nil on Errno::ETIMEDOUT" do
      GT::Arnold::BeanJob.stub(:bean).and_return(mock_model("BeanConexion").stub(:reserve).and_throw(Errno::ETIMEDOUT))
      GT::Arnold::BeanJob.stub(:reset_bean)
      GT::Arnold::BeanJob.get_and_delete_job.should == nil
    end
    
    it "should reset bean and return nil on Beanstalk::NotConnected" do
      GT::Arnold::BeanJob.stub(:bean).and_return(mock_model("BeanConexion").stub(:reserve).and_throw(Beanstalk::NotConnected))
      GT::Arnold::BeanJob.stub(:reset_bean)
      GT::Arnold::BeanJob.get_and_delete_job.should == nil
    end
    
    it "should return nil on any other exception"  do
      GT::Arnold::BeanJob.stub(:bean).and_return(mock_model("BeanConexion").stub(:reserve).and_throw(Exception))
      GT::Arnold::BeanJob.get_and_delete_job.should == nil
    end
    
  end
  
  context "parse_job" do
    before(:each) do
      @body_hash = {
        'url' => 'some://url',
        'provider_type' => 'pro',
        'provider_user_id' => 'pro_id_1',
        }
    end
    
    it "should URI unescape then JSON parse the job" do
      URI.stub(:unescape).with(:job_body).and_return(:job_body_unescaped)
      JSON.stub(:parse).with(:job_body_unescaped).and_return(@body_hash)
      GT::Arnold::BeanJob.parse_job(mock_model("MJob", :body => :job_body, :jobid => :id))
    end
    
    it "should pull url, provider_type, provider_user_id from json" do
      @body_hash['twitter_status_update'] = :whatever
      parsed = GT::Arnold::BeanJob.parse_job(mock_model("MJob", :body => URI.escape(@body_hash.to_json), :jobid => :id))
      parsed[:url].should == 'some://url'
      parsed[:provider_type].should == 'pro'
      parsed[:provider_user_id].should == 'pro_id_1'
    end
    
    it "should pull multiple :expanded_urls from twitter status if provided" do
      @body_hash['twitter_status_update'] = {
        'text' => "boo",
        'entities' => {
          'urls' => [
            {'display' => 'x', 'expanded_url' => 'url1'},
            {'display' => 'y', 'expanded_url' => 'url2'},
            {'display' => 'z', 'expanded_url' => 'url3'}]
        }}
        
        parsed = GT::Arnold::BeanJob.parse_job(mock_model("MJob", :body => URI.escape(@body_hash.to_json), :jobid => :id))
        parsed[:expanded_urls].class.should == Array
        parsed[:expanded_urls].size.should == 3
        parsed[:expanded_urls].should include('url1')
        parsed[:expanded_urls].should include('url2')
        parsed[:expanded_urls].should include('url3')
    end
    
    it "should not choke if entities includes no urls" do
      @body_hash['twitter_status_update'] = {
        'text' => "boo",
        'entities' => {}}
        
        parsed = GT::Arnold::BeanJob.parse_job(mock_model("MJob", :body => URI.escape(@body_hash.to_json), :jobid => :id))
        parsed[:expanded_urls].should == nil
    end
    
    it "should not create :expanded_urls if it would be empty" do
      @body_hash['twitter_status_update'] = {
        'text' => "boo",
        'entities' => {
          'urls' => [
            {'display' => 'x'},
            {'display' => 'y'},
            {'display' => 'z'}]
        }}
        
        parsed = GT::Arnold::BeanJob.parse_job(mock_model("MJob", :body => URI.escape(@body_hash.to_json), :jobid => :id))
        parsed[:expanded_urls].should == nil
    end
    
    it "should pull twitter_status_update from json" do
      @body_hash['twitter_status_update'] = :whatever
      parsed = GT::Arnold::BeanJob.parse_job(mock_model("MJob", :body => URI.escape(@body_hash.to_json), :jobid => :id))
      parsed[:twitter_status_update].should == "whatever"
    end
    
    it "should pull facebook_status_update from json" do
      @body_hash['facebook_status_update'] = :whatever
      parsed = GT::Arnold::BeanJob.parse_job(mock_model("MJob", :body => URI.escape(@body_hash.to_json), :jobid => :id))
      parsed[:facebook_status_update].should == "whatever"
    end
    
    it "should pull tumblr_status_update from json" do
      @body_hash['tumblr_status_update'] = :whatever
      parsed = GT::Arnold::BeanJob.parse_job(mock_model("MJob", :body => URI.escape(@body_hash.to_json), :jobid => :id))
      parsed[:tumblr_status_update].should == "whatever"
    end
    
    it "should return false unless job has a status update" do
      GT::Arnold::BeanJob.parse_job(mock_model("MJob", :body => URI.escape(@body_hash.to_json), :jobid => :id)).should == false
    end
    
    it "should return false unless job has url" do
      @body_hash['url'] = nil
      GT::Arnold::BeanJob.parse_job(mock_model("MJob", :body => URI.escape(@body_hash.to_json), :jobid => :id)).should == false
    end
    
    it "should return false unless job has provider_type" do
      @body_hash['provider_type'] = nil
      GT::Arnold::BeanJob.parse_job(mock_model("MJob", :body => URI.escape(@body_hash.to_json), :jobid => :id)).should == false
    end
    
    it "should return false unless job has provider_user_id" do
      @body_hash['provider_user_id'] = nil
      GT::Arnold::BeanJob.parse_job(mock_model("MJob", :body => URI.escape(@body_hash.to_json), :jobid => :id)).should == false
    end

  end
  
end
  
  