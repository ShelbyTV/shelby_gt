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
      GT::UrlHelper.get_clean_url("facebook.com").should == nil
    end
    
  end
  
  context "parse_url_for_provider_info" do
    
    it "should accept bad urls and return nil" do
      GT::UrlHelper.parse_url_for_provider_info(nil).should == nil
      GT::UrlHelper.parse_url_for_provider_info("").should == nil
    end
    
    it "should return nil for urls it can't handle" do
      GT::UrlHelper.parse_url_for_provider_info("http://danspinosa.com/v/Hl-zzrqQoSE").should == nil
      GT::UrlHelper.parse_url_for_provider_info("https://danspinosa.com/v/Hl-zzrqQoSE").should == nil
    end
    
    context "Shelby SEO pages" do
      it "Should parse Shelby SEO pages for YouTube" do
        GT::UrlHelper.parse_url_for_provider_info("http://shelby.tv/video/youtube/HDTwQGEeGZc").should == 
          {:provider_name => "youtube", :provider_id => "HDTwQGEeGZc"}
      end

      it "Should generically parse Shelby SEO pages for all providers" do
        #HTTP, provider name becomes all lowercase
        GT::UrlHelper.parse_url_for_provider_info("http://shelby.tv/video/RandomProvider/HDTwQGEeGZc").should == 
          {:provider_name => "randomprovider", :provider_id => "HDTwQGEeGZc"}
        #HTTPS
        GT::UrlHelper.parse_url_for_provider_info("https://shelby.tv/video/RandomProvider/HDTwQGEeGZc").should == 
          {:provider_name => "randomprovider", :provider_id => "HDTwQGEeGZc"}
          
        GT::UrlHelper.parse_url_for_provider_info("https://shelby.tv/video/Random.Provider/HDTwQGEeGZc").should == 
          {:provider_name => "random.provider", :provider_id => "HDTwQGEeGZc"}
          
        GT::UrlHelper.parse_url_for_provider_info("https://shelby.tv/video/Random-Provider/HDTwQGEeGZc").should == 
          {:provider_name => "random-provider", :provider_id => "HDTwQGEeGZc"}
          
        GT::UrlHelper.parse_url_for_provider_info("https://shelby.tv/video/Rand0m_Provider/HDTwQGEeGZc").should == 
          {:provider_name => "rand0m_provider", :provider_id => "HDTwQGEeGZc"}
      end
      
      it "should not be triped up by shit at the end of the Shelby SEO url" do
        GT::UrlHelper.parse_url_for_provider_info("https://shelby.tv/video/Rand0m_Provider/HDTwQGEeGZc?a=b").should == 
          {:provider_name => "rand0m_provider", :provider_id => "HDTwQGEeGZc"}
          
        GT::UrlHelper.parse_url_for_provider_info("https://shelby.tv/video/Rand0m_Provider/HDTwQGEeGZc/whatever").should == 
          {:provider_name => "rand0m_provider", :provider_id => "HDTwQGEeGZc"}
        GT::UrlHelper.parse_url_for_provider_info("https://shelby.tv/video/Rand0m_Provider/HDTwQGEeGZc//").should == 
          {:provider_name => "rand0m_provider", :provider_id => "HDTwQGEeGZc"}
      end
    end
    
    context "youtube" do
      it "should parse long youtube urls" do
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
      
      it "should parse youtube CAPTCHA urls" do
        GT::UrlHelper.parse_url_for_provider_info("http://www.youtube.com/das_captcha?next=/watch?v=780llTKt3uM%26feature=share").should == 
          {:provider_name => "youtube", :provider_id => "780llTKt3uM"}
      end
    
      it "should parse youtube shortlink urls" do
        GT::UrlHelper.parse_url_for_provider_info("http://youtu.be/L7jduDKGWUc?version=3").should == 
          {:provider_name => "youtube", :provider_id => "L7jduDKGWUc"}
        GT::UrlHelper.parse_url_for_provider_info("http://youtu.be/L7jduDKGWUc").should == 
          {:provider_name => "youtube", :provider_id => "L7jduDKGWUc"}
      end
    
      it "should parse youtube embed html" do
        GT::UrlHelper.parse_url_for_provider_info('<embed src="http://www.youtube.com/e/nTFEUsudhfs" type="application/x-shockwave-flash" ... >').should == 
          {:provider_name => "youtube", :provider_id => "nTFEUsudhfs"}
        GT::UrlHelper.parse_url_for_provider_info('...embed src=\"http://www.youtube.com/v/L7jduDKGWUc?version=3\" type=\"applic...').should == 
          {:provider_name => "youtube", :provider_id => "L7jduDKGWUc"}
      end
    end
    
    context "vimeo" do
      it "should parse long vimeo urls" do
        GT::UrlHelper.parse_url_for_provider_info("http://vimeo.com/19819283").should == 
          {:provider_name => "vimeo", :provider_id => "19819283"}
        GT::UrlHelper.parse_url_for_provider_info("http://vimeo.com/hd#19819283").should == 
          {:provider_name => "vimeo", :provider_id => "19819283"}
        GT::UrlHelper.parse_url_for_provider_info("http://vimeo.com/groups/aftereffects/videos/19878538").should == 
          {:provider_name => "vimeo", :provider_id => "19878538"}
      end
      
      it "should parse vimeo moogaloop with clip_id" do
        GT::UrlHelper.parse_url_for_provider_info("http://vimeo.com/moogaloop.swf?clip_id=39752759&autoplay=1").should == 
          {:provider_name => "vimeo", :provider_id => "39752759"}
      end
      
      it "should parse vimeo iframe embeds" do
        GT::UrlHelper.parse_url_for_provider_info('<iframe src="http://player.vimeo.com/video/19799531" width="1280" height="720" frameborder="0"></iframe>').should == 
          {:provider_name => "vimeo", :provider_id => "19799531"}
      end
    end
    
    context "dailymotion" do
      it "should parse from url" do
        GT::UrlHelper.parse_url_for_provider_info('http://www.dailymotion.com/video/xped0i_what-s-up-with-gaga-tell-all-book-biopic-coming_music').should == 
          {:provider_name => "dailymotion", :provider_id => "xped0i"}
      end
      
      it "should parse from html" do
        GT::UrlHelper.parse_url_for_provider_info('<iframe src=\"http://www.dailymotion.com/embed/video/xp47ne\" width=\"480\" height=\"269\" frameborder=\"0\"></iframe>').should == 
          {:provider_name => "dailymotion", :provider_id => "xp47ne"}
        
        GT::UrlHelper.parse_url_for_provider_info("<iframe src=\"http://www.dailymotion.com/embed/video/xwdcq\" width=\"480\" height=\"288\" frameborder=\"0\"></iframe>").should == 
          {:provider_name => "dailymotion", :provider_id => "xwdcq"}
      end
      
      it "should parse from embeds" do
        GT::UrlHelper.parse_url_for_provider_info('<iframe src=\"http://www.dailymotion.com/embed/video/xh31mt?autoPlay=0\" width=\"480\" height=\"224\" frameborder=\"0\"></iframe>').should == 
          {:provider_name => "dailymotion", :provider_id => "xh31mt"}
      end
    end
    
    context "blip.tv" do      
      it "should parse from embed" do
        GT::UrlHelper.parse_url_for_provider_info('<iframe src="http://blip.tv/episode/AYLu4BYC.html?p=1" width="550" height="443" frameborder="0" allowfullscreen></iframe><embed type="application/x-shockwave-flash" src="http://a.blip.tv/api.swf#AYLu4BYC" style="display:none"></embed>').should == 
          {:provider_name => "bliptv", :provider_id => "AYLu4BYC"}
      end
    end
    
    context "techcrunch" do
      it "should parse from url" do
        GT::UrlHelper.parse_url_for_provider_info('http://techcrunch.tv/new-and-featured/watch?id=Uwanl4MTohKEfg0NayBoDIQyaybdeRXd').should == 
          {:provider_name => "techcrunch", :provider_id => "Uwanl4MTohKEfg0NayBoDIQyaybdeRXd"}
        GT::UrlHelper.parse_url_for_provider_info('http://techcrunch.tv/watch?id=Uwanl4MTohKEfg0NayBoDIQyaybdeRXd').should == 
          {:provider_name => "techcrunch", :provider_id => "Uwanl4MTohKEfg0NayBoDIQyaybdeRXd"}
        GT::UrlHelper.parse_url_for_provider_info('http://techcrunch.com/2012/03/15/tctv-in-mobile-travel/#ooid=JjMGNqMzoi3EYOwAtV8uhVfEjmCuCV7j').should == 
          {:provider_name => "techcrunch", :provider_id => "JjMGNqMzoi3EYOwAtV8uhVfEjmCuCV7j"}
      end
    end
    
    context "college humor" do
      it "should parse from url" do
        GT::UrlHelper.parse_url_for_provider_info('http://www.collegehumor.com/video/6741583/very-mary-kate-dishwasher').should == 
          {:provider_name => "collegehumor", :provider_id => "6741583"}
      end
      
      it "should parse from embed" do
        GT::UrlHelper.parse_url_for_provider_info('<iframe src="http://www.collegehumor.com/e/6741583" width="600" height="338" frameborder="0" webkitAllowFullScreen allowFullScreen></iframe>').should == 
          {:provider_name => "collegehumor", :provider_id => "6741583"}
        GT::UrlHelper.parse_url_for_provider_info('<object type="application/x-shockwave-flash" data="http://www.collegehumor.com/moogaloop/moogaloop.swf?clip_id=2925369&fullscreen=1&use_node_id=true" width=...').should == 
          {:provider_name => "collegehumor", :provider_id => "2925369"}
      end
    end
    
    context "hulu" do
      it "should parse from url" do
        GT::UrlHelper.parse_url_for_provider_info('http://www.hulu.com/watch/339016/modern-family-send-out-the-clowns').should == 
          {:provider_name => "hulu", :provider_id => "339016"}
      end
      
      it "should parse from thumbnail url" do
        GT::UrlHelper.parse_url_for_provider_info('http://thumbnails.hulu.com/619/40021619/40021619_145x80_generated.jpg').should == 
          {:provider_name => "hulu", :provider_id => "40021619"}
      end
    end
    
    context "ooyala" do
      it "should parse from embed" do
        # from Bloomberg
        GT::UrlHelper.parse_url_for_provider_info('<script src="http://player.ooyala.com/player.js?width=640&deepLinkEmbedCode=JiZjMxNDo_k2WncC2C_Jt_n22nA1S1RT&height=360&embedCode=JiZjMxNDo_k2WncC2C_Jt_n22nA1S1RT"></script>').should == 
          {:provider_name => "ooyala", :provider_id => "JiZjMxNDo_k2WncC2C_Jt_n22nA1S1RT"}
        
        #from TechCrunch
        GT::UrlHelper.parse_url_for_provider_info('<script src="http://player.ooyala.com/player.js?width=640&deepLinkEmbedCode=JjMGNqMzoi3EYOwAtV8uhVfEjmCuCV7j&embedCode=JjMGNqMzoi3EYOwAtV8uhVfEjmCuCV7j&height=360"></script>').should == 
          {:provider_name => "ooyala", :provider_id => "JjMGNqMzoi3EYOwAtV8uhVfEjmCuCV7j"}
      end
    end
    
    context "espn" do
      it "should parse from url" do
        GT::UrlHelper.parse_url_for_provider_info('http://espn.go.com/video/clip?id=7940079').should == 
          {:provider_name => "espn", :provider_id => "7940079"}
      end      
    end
    
    context "bloomberg" do
      it "should parse from url" do
        GT::UrlHelper.parse_url_for_provider_info('http://www.bloomberg.com/video/zoom-how-google-fiber-could-change-everything-gf5dlnyCTPGwmNQrL7DS9w.html?bloomberg_ooyala_id=prd2RlNzqmhRZJrn6J7LxdPqig0SaFgO').should == 
          {:provider_name => "ooyala", :provider_id => "prd2RlNzqmhRZJrn6J7LxdPqig0SaFgO"}
      end      
    end
    
  end
  
  context "resolve_url" do
    
    context "with Net::HTTP" do
    
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
      
    end
    
    context "with EventMachine" do
      
      it "should work without cache" do
        url1 = "http://fake1.com"
        url2 = "http://fake2.net"
        
        #TODO: mock stuff
        fake_em_http_request = mock_model("FakeEMHttpRequest")
        fake_em_http_request.stub( :head ).and_return(
          mock_model("FakeEMHttpResponse", :last_effective_url => mock_model("FakeResponseHeader", :normalize => url2) )
          )
        EventMachine::HttpRequest.stub(:new).with( url1, {:connect_timeout => Settings::EventMachine.connect_timeout} ).and_return( fake_em_http_request )
        
        GT::UrlHelper.resolve_url(url1, true, nil).should == url2
      end
      
    end
    
    context "with cache" do
    
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
    
    end
    
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
