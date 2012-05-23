require 'spec_helper'
require 'deep_link_parser'

describe GT::DeepLinkParser do
  before(:all) do
    @deeplink = "http://www.youtube.com/embed/lMBMcMf85ow?version=3&rel=1&fs=1&showsearch=0&showinfo=1&iv_load_policy=1&wmode=transparent"

    @url ="http://deadwildroses.wordpress.com/2012/05/21/another-light-blogging-week-moving/"
      
    @v = Video.new
    @v.provider_name = "pro1"
    @v.provider_id = "132443"
    @v.save

    @dl =GT::DeeplinkCache.new
    @dl.url = "cachedurl"
    @dl.videos = ["deepurl1"]
    @dl.time = Time.now
    @dl.save
  end


  context "check_cached" do
    it "should return cached url" do
      GT::DeepLinkParser.find_deep_link(@dl.url).should == @dl.videos
    end
  end

  context "parse_deep" do
    it "should parse deep corecctly" do
      puts GT::DeepLinkParser.find_deep_link(@url)
      GT::DeepLinkParser.find_deep_link(@url).should == [@deeplink]
    end

    it "should find something" do
      found = GT::DeepLinkParser.find_deep_link("http://www.fastcoexist.com/1679878/mits-freaky-non-stick-coating-keeps-ketchup-flowing")
      puts found
      found.empty?.should == false
      dl = GT::DeeplinkCache.where(:url => @url).first
      puts dl[:url]
      puts dl[:videos]


    end
    it "should be cached" do
      GT::DeeplinkCache.where(:url => @url).first[:url].should == @url
    end
  end
end
      
    


