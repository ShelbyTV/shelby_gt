require 'spec_helper'

require 'memcached_link_resolving_cache'

# UNIT test
describe MemcachedLinkResolvingCache do
  before(:each) do
    @memcache_mock = mock_model("MCM")
  end
  
  context "create" do
    it "should throw argument error without :original_url" do
      lambda {
        MemcachedLinkResolvingCache.create({:resolved_url => "a"}, nil)
      }.should raise_error(ArgumentError)
    end
    
    it "should throw argument exception without :resolved_url" do
      lambda {
        MemcachedLinkResolvingCache.create({:original_url => "a"}, nil)
      }.should raise_error(ArgumentError)
    end
    
    it "should try to store the resolved url" do
      @memcache_mock.stub(:add).and_return(true)
      MemcachedLinkResolvingCache.create({:original_url => "a", :resolved_url => "b"}, @memcache_mock)
    end
    
    it "should gracefully handle Memcached::NotStored" do
      @memcache_mock.stub(:add).and_raise(Memcached::NotStored)
      MemcachedLinkResolvingCache.create({:original_url => "a", :resolved_url => "b"}, @memcache_mock)
    end
  end
  
  context "find_by_original_url" do
    it "should try to get key from memcached" do
      @memcache_mock.stub(:get).and_return(nil)
      MemcachedLinkResolvingCache.find_by_original_url("blah", @memcache_mock).should == nil
    end
    
    it "should return nil on Memcached::NotFound" do
      @memcache_mock.stub(:get).and_raise(Memcached::NotFound)
      MemcachedLinkResolvingCache.find_by_original_url("blah", @memcache_mock).should == nil
    end
    
    it "should gracefully handle unexpected memcached non-hash return" do
      @memcache_mock.stub(:get).and_return(4)
      MemcachedLinkResolvingCache.find_by_original_url("blah", @memcache_mock).should == nil
    end
    
    it "should gracefully handle unexpected memcached hash return" do
      @memcache_mock.stub(:get).and_return({:not_expected => "blah"})
      res = MemcachedLinkResolvingCache.find_by_original_url("blah", @memcache_mock)
      res.should be_instance_of(MemcachedLinkResolvingCache)
    end
    
    it "should return MemcachedLinkResolvingCache on cache hit" do
      @memcache_mock.stub(:get).and_return({MemcachedLinkResolvingCache::RESOLVED_URL_FIELD => "blah"})
      res = MemcachedLinkResolvingCache.find_by_original_url("blah", @memcache_mock)
      res.should be_instance_of(MemcachedLinkResolvingCache)
    end
    
    it "should store url in MemcachedLinkResolvingCache as .resolved_url" do
      @memcache_mock.stub(:get).and_return({MemcachedLinkResolvingCache::RESOLVED_URL_FIELD => "blah2"})
      res = MemcachedLinkResolvingCache.find_by_original_url("blah", @memcache_mock)
      res.should be_instance_of(MemcachedLinkResolvingCache)
      res.resolved_url.should == "blah2"
    end
    
    it "should handle nil url" do
      res = MemcachedLinkResolvingCache.find_by_original_url(nil, @memcache_mock)
      res.should be_nil
    end
  end
  
end