require 'spec_helper'

require 'memcached_video_processing_link_cache'

# UNIT test
describe MemcachedVideoProcessingLinkCache do
  before(:each) do
    @memcache_mock = mock_model("MCM")
  end
  
  context "create" do
    it "should throw argument error without :url" do
      lambda {
        MemcachedVideoProcessingLinkCache.create({:embedly_json => "a"}, nil)
      }.should raise_error(ArgumentError)
    end
      
    it "should throw argument error without :embedly_json" do
      lambda {
        MemcachedVideoProcessingLinkCache.create({:url => "b"}, nil)
      }.should raise_error(ArgumentError)
    end
    
    it "should try to store the embed.ly json" do
      @memcache_mock.stub(:add).and_return(true)
      MemcachedVideoProcessingLinkCache.create({:url => "a", :embedly_json => "b"}, @memcache_mock)
    end
    
    it "should gracefully handle Memcached::NotStored" do
      @memcache_mock.stub(:add).and_raise(Memcached::NotStored)
      MemcachedVideoProcessingLinkCache.create({:url => "a", :embedly_json => "b"}, @memcache_mock)
    end
    
  end
  
  context "find_by_url" do
    it "should try to get key from memcached" do
      @memcache_mock.stub(:get).and_return(nil)
      MemcachedVideoProcessingLinkCache.find_by_url("blah", @memcache_mock).should == nil
    end
    
    it "should return nil on Memcached::NotFound" do
      @memcache_mock.stub(:get).and_raise(Memcached::NotFound)
      MemcachedVideoProcessingLinkCache.find_by_url("blah", @memcache_mock).should == nil
    end
    
    it "should gracefully handle unexpected memcached non-hash return" do
      @memcache_mock.stub(:get).and_return(4)
      MemcachedVideoProcessingLinkCache.find_by_url("blah", @memcache_mock).should == nil
    end
    
    it "should gracefully handle unexpected memcached hash return" do
      @memcache_mock.stub(:get).and_return({:not_expected => "blah"})
      res = MemcachedVideoProcessingLinkCache.find_by_url("blah", @memcache_mock)
      res.should be_instance_of(MemcachedVideoProcessingLinkCache)
    end
    
    it "should return MemcachedLinkResolvingCache on cache hit" do
      @memcache_mock.stub(:get).and_return({MemcachedVideoProcessingLinkCache::EMBEDLY_FIELD => "blah"})
      res = MemcachedVideoProcessingLinkCache.find_by_url("blah", @memcache_mock)
      res.should be_instance_of(MemcachedVideoProcessingLinkCache)
    end
    
    it "should store url in MemcachedLinkResolvingCache as .embedly_json" do
      @memcache_mock.stub(:get).and_return({MemcachedVideoProcessingLinkCache::EMBEDLY_FIELD => "blah2"})
      res = MemcachedVideoProcessingLinkCache.find_by_url("blah", @memcache_mock)
      res.should be_instance_of(MemcachedVideoProcessingLinkCache)
      res.embedly_json.should == "blah2"
    end
  end
  
end