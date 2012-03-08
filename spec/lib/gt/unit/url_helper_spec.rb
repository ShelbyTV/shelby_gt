require 'spec_helper'

require 'url_helper'
require 'memcached_link_resolving_cache'

# UNIT test
describe GT::UrlHelper do
  
  context "get_clean_url" do
  
    it "should add http to url w/o it" do
      GT::UrlHelper.get_clean_url("danspinosa.com").should == "http://danspinosa.com"
    end
  
    it "should not touch http or https" do
      GT::UrlHelper.get_clean_url("http://danspinosa.com").should == "http://danspinosa.com"
      GT::UrlHelper.get_clean_url("https://danspinosa.com").should == "https://danspinosa.com"
    end
    
    it "should return nil if url is blacklisted" do
      GT::UrlHelper.get_clean_url("freq.ly").should == nil
      GT::UrlHelper.get_clean_url("yfrog.").should == nil
      GT::UrlHelper.get_clean_url("4sq.com").should == nil
      GT::UrlHelper.get_clean_url("twitpic.com").should == nil
      GT::UrlHelper.get_clean_url("nyti.ms").should == nil
      GT::UrlHelper.get_clean_url("plixi.com").should == nil
      GT::UrlHelper.get_clean_url("instagr.am").should == nil
    end
    
  end
  
  context "parse_url_for_provider_info" do
    
    it "should correctly parse long youtube urls" do
      GT::UrlHelper.parse_url_for_provider_info("https://www.youtube-nocookie.com/embed/Hl-zzrqQoSE").should == 
        {:provider_name => "youtube", :provider_id => "Hl-zzrqQoSE"}
      GT::UrlHelper.parse_url_for_provider_info("https://www.youtube.com/embed/Hl-zzrqQoSE").should == 
        {:provider_name => "youtube", :provider_id => "Hl-zzrqQoSE"}
      GT::UrlHelper.parse_url_for_provider_info("https://www.youtube.com/v/Hl-zzrqQoSE").should == 
        {:provider_name => "youtube", :provider_id => "Hl-zzrqQoSE"}
      GT::UrlHelper.parse_url_for_provider_info("http://www.youtube-nocookie.com/v/Hl-zzrqQoSE?version=3&amp;hl=en_US&amp;rel=0").should == 
        {:provider_name => "youtube", :provider_id => "Hl-zzrqQoSE"}
      GT::UrlHelper.parse_url_for_provider_info("http://www.youtube.com/v/Hl-zzrqQoSE?version=3&amp;hl=en_US&amp;rel=0").should == 
        {:provider_name => "youtube", :provider_id => "Hl-zzrqQoSE"}
      GT::UrlHelper.parse_url_for_provider_info("http://www.youtube.com/v/p4d-SNTGxLw").should == 
        {:provider_name => "youtube", :provider_id => "p4d-SNTGxLw"}
      GT::UrlHelper.parse_url_for_provider_info("http://www.youtube.com/v/1fouvwilGWc&fs=0&source=uds").should == 
        {:provider_name => "youtube", :provider_id => "1fouvwilGWc"}
      GT::UrlHelper.parse_url_for_provider_info("http://www.youtube.com/watch?v=8lq94xEMMEc&feature=g-vrec&context=G29d54d5RVAAAAAAAAAQ").should == 
        {:provider_name => "youtube", :provider_id => "8lq94xEMMEc"}
      GT::UrlHelper.parse_url_for_provider_info("http://www.youtube.com/watch?v=EK9ccsb8yPg&feature=featured").should == 
        {:provider_name => "youtube", :provider_id => "EK9ccsb8yPg"}
      GT::UrlHelper.parse_url_for_provider_info("http://m.youtube.com/watch?gl=US&hl=en&client=mv-google&v=DBjrMNER9gQ").should == 
        {:provider_name => "youtube", :provider_id => "DBjrMNER9gQ"}
      GT::UrlHelper.parse_url_for_provider_info("http://www.youtube.com/e/nTFEUsudhfs").should == 
        {:provider_name => "youtube", :provider_id => "nTFEUsudhfs"}
      GT::UrlHelper.parse_url_for_provider_info("http://www.youtube.com/v/L7jduDKGWUc?version=3").should == 
        {:provider_name => "youtube", :provider_id => "L7jduDKGWUc"}
      GT::UrlHelper.parse_url_for_provider_info("http://www.youtube.com/watch?v=6dncx6O5J4U&feature=youtu.be").should == 
        {:provider_name => "youtube", :provider_id => "6dncx6O5J4U"}
    end  
    
    it "should correctly parse youtube shortlink urls" do
      GT::UrlHelper.parse_url_for_provider_info("http://youtu.be/L7jduDKGWUc?version=3").should == 
        {:provider_name => "youtube", :provider_id => "L7jduDKGWUc"}
      GT::UrlHelper.parse_url_for_provider_info("http://youtu.be/L7jduDKGWUc").should == 
        {:provider_name => "youtube", :provider_id => "L7jduDKGWUc"}
    end

    it "should return nil for urls it can't handle" do
      GT::UrlHelper.parse_url_for_provider_info("https://danspinosa.com/v/Hl-zzrqQoSE").should == nil
    end
    
  end
  
  context "resolve_url" do
    
    it "should work without cache" do
      #This is a real resolve that hits the www, which should never be in tests:
      #GT::UrlHelper.resolve_url("http://shel.tv", false, nil).should == "http://shelby.tv"
      
      # Instead, we mock up a couple redirects and make sure she works...
      
      url1 = "http://fake1.com"
      url2 = "http://fake2.net"
      url3 = "http://fake3.org"
      
      r1to2 = Net::HTTPMovedPermanently.new("1", "301", "x")
      r1to2['location'] = url2
      Net::HTTP.stub( :get_response, url1).and_return(r1to2)
      r2to3 = Net::HTTPMovedPermanently.new("1", "301", "x")
      r2to3['location'] = url3
      Net::HTTP.stub( :get_response, url2).and_return(r2to3)
      
      GT::UrlHelper.resolve_url(url1, false, nil).should == url3
    end
    
    it "should return directly from cache" do
      url1 = "http://xfake1.com"
      url3 = "http://xfake3.org"
      
      MemcachedLinkResolvingCache.stub( :find_by_original_url ).with(url1, :fake_memcache).and_return(
        mock_model("MockMemcachedLinkResolvingCache", :resolved_url => url3)
        )

      GT::UrlHelper.resolve_url(url1, false, :fake_memcache).should == url3
    end
    
    it "should save url resolution to cache" do
      url1 = "http://yfake1.com"
      url3 = "http://yfake3.org"
      
      # no cache hit
      MemcachedLinkResolvingCache.stub( :find_by_original_url ).with(url1, :fake_memcache).and_return(nil)
        
      #fake resolution
      r1to3 = Net::HTTPMovedPermanently.new("1", "301", "x")
      r1to3['location'] = url3
      Net::HTTP.stub( :get_response, url1).and_return(r1to3)
      
      #expect save to cache
      MemcachedLinkResolvingCache.stub( :create ).with( {:original_url => url1, :resolved_url => url3}, :fake_memcache)

      GT::UrlHelper.resolve_url(url1, false, :fake_memcache).should == url3
    end
    
    it "should be able to resolve with EventMachine"
    
  end
  
  context "post_process_url" do
    
    it "should transform vimeo channel urls" do
      GT::UrlHelper.post_process_url("http://vimeo.com/channels/hdgirls#30492458").should == "http://vimeo.com/30492458"
    end
    
    it "should not touch other urs" do
      GT::UrlHelper.post_process_url("absd").should == "absd"
      GT::UrlHelper.post_process_url("http://danspinosa.com").should == "http://danspinosa.com"
      GT::UrlHelper.post_process_url("https://danspinosa.com").should == "https://danspinosa.com"
    end
    
  end
  
  context "url_is_shelby" do
    
    it "should recognize shelby.tv and shel.tv links" do
      GT::UrlHelper.url_is_shelby?("http://shelby.tv/#!/whatever").should == true
      GT::UrlHelper.url_is_shelby?("http://shelby.tv/whatever").should == true
      GT::UrlHelper.url_is_shelby?("http://shelby.tv").should == true
      
      GT::UrlHelper.url_is_shelby?("http://shel.tv/xyz123").should == true
      GT::UrlHelper.url_is_shelby?("http://shel.tv").should == true
    end
    
  end
  
end