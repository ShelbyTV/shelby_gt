require 'spec_helper'

require 'url_video_detector'
require 'memcached_video_processing_link_cache'

# UNIT test
describe GT::UrlVideoDetector do
  
  before(:each) do
    @url = "http://www.youtube.com/watch?v=Z3uD6w9kvZI"
    @embedly_url = "http://api.embed.ly/1/oembed?url=#{CGI.escape(@url)}&format=json&key=#{Settings::Embedly.key}"
  end
  
  context "embedly" do
    
    it "should correctly generate embed.ly url" do
      URI.should_receive( :parse ).with( @embedly_url )
      Net::HTTP.stub( :get_response ).and_return( nil )
      
      GT::UrlVideoDetector.examine_url_for_video(@url, false, nil).should == nil
    end
    
    context "net http" do
      it "should handle success" do
        embedly_hash = {"some" => "thing", "fake" => true}
        Net::HTTP.stub( :get_response ).and_return( mock_model("FakeResponse", :code => "200", :body => embedly_hash.to_json) )
        
        GT::UrlVideoDetector.examine_url_for_video(@url, false, nil).should == [{:embedly_hash => embedly_hash}]
      end
      
      it "should handle 404" do
        embedly_hash = {"some" => "thing", "fake" => true}
        Net::HTTP.stub( :get_response ).and_return( mock_model("FakeResponse", :code => "404") )
        
        GT::UrlVideoDetector.examine_url_for_video(@url, false, nil).should == nil
      end
      
      it "should handle other crap outs" do
        embedly_hash = {"some" => "thing", "fake" => true}
        Net::HTTP.stub( :get_response ).and_return( mock_model("FakeResponse", :code => "500") )
        
        GT::UrlVideoDetector.examine_url_for_video(@url, false, nil).should == nil
      end
    end
    
    context "event machine" do
      it "should handle success" do
        embedly_hash = {"some" => "thing", "fake" => true}
        
        fake_em_http_request = mock_model("FakeEMHttpRequest")
        fake_em_http_request.stub( :get ).with({:head=>{'User-Agent'=>Settings::Embedly.user_agent}}).and_return(
          mock_model("FakeEMHttpResponse", :error => false, :response_header => mock_model("FakeResponseHeader", :status => 200), :response => embedly_hash.to_json )
          )
        EventMachine::HttpRequest.stub( :new ).and_return( fake_em_http_request )
        
        GT::UrlVideoDetector.examine_url_for_video(@url, true, nil).should == [{:embedly_hash => embedly_hash}]
      end
      
      it "should handle 404" do
        embedly_hash = {"some" => "thing", "fake" => true}
        
        fake_em_http_request = mock_model("FakeEMHttpRequest")
        fake_em_http_request.stub( :get ).with({:head=>{'User-Agent'=>Settings::Embedly.user_agent}}).and_return(
          mock_model("FakeEMHttpResponse", :error => false, :response_header => mock_model("FakeResponseHeader", :status => 404) )
          )
        EventMachine::HttpRequest.stub( :new ).and_return( fake_em_http_request )
        
        GT::UrlVideoDetector.examine_url_for_video(@url, true, nil).should == nil
      end
      
      it "should try 5 times w/ exponential backoff if embed.ly fails" do
        embedly_hash = {"some" => "thing", "fake" => true}
        
        fake_em_http_request = mock_model("FakeEMHttpRequest")
        fake_em_http_request.stub( :get ).with({:head=>{'User-Agent'=>Settings::Embedly.user_agent}}).and_return(
          mock_model("FakeEMHttpResponse", :error => true, :response_header => mock_model("FakeResponseHeader", :status => 500), :response => "fuck" )
          )
        EventMachine::HttpRequest.stub( :new ).and_return( fake_em_http_request )
        
        EventMachine::Synchrony.should_receive(:sleep).exactly(5).times
        
        GT::UrlVideoDetector.examine_url_for_video(@url, true, nil).should == nil
      end
    end
    
  end
  
  context "examine_url_for_video" do
    
    it "should return embed.ly hash with json if we hit cache" do
      embedly_hash = {"some" => "thing", "fake" => true}
      
      MemcachedVideoProcessingLinkCache.stub( :find_by_url ).with(@url, :fake_client).and_return(
        mock_model("FakeMemcachedVideoProcessingLinkCache", :embedly_json => embedly_hash.to_json)
        )
      
      GT::UrlVideoDetector.examine_url_for_video(@url, false, :fake_client).should == [{:embedly_hash => embedly_hash}]
    end
    
    it "should return embed.ly hash with nil if we hit cache and have cached a nil" do
      MemcachedVideoProcessingLinkCache.stub( :find_by_url ).with(@url, :fake_client).and_return(
        mock_model("FakeMemcachedVideoProcessingLinkCache", :embedly_json => nil)
        )
      
      GT::UrlVideoDetector.examine_url_for_video(@url, false, :fake_client).should == nil
    end
    
    context "net http" do
      it "should save valid embed.ly response to cache" do
        embedly_hash = {"some" => "thing", "fake" => true}
        Net::HTTP.stub( :get_response ).and_return( mock_model("FakeResponse", :code => "200", :body => embedly_hash.to_json) )

        #expect caching#
        GT::UrlVideoDetector.should_receive(:add_link_to_video_processing_cache).with(@url, embedly_hash.to_json, :fake_client)

        GT::UrlVideoDetector.examine_url_for_video(@url, false, :fake_client).should == [{:embedly_hash => embedly_hash}]
      end
    
      it "should save nil to cache on 404" do
        embedly_hash = {"some" => "thing", "fake" => true}
        Net::HTTP.stub( :get_response ).and_return( mock_model("FakeResponse", :code => "404") )

        #expect nil caching#
        GT::UrlVideoDetector.should_receive(:add_link_to_video_processing_cache).with(@url, nil, :fake_client)

        GT::UrlVideoDetector.examine_url_for_video(@url, false, :fake_client).should == nil
      end
    end
    
    context "event machine" do
      it "should save valid embed.ly response to cache"  do
        embedly_hash = {"some" => "thing", "fake" => true}
        
        fake_em_http_request = mock_model("FakeEMHttpRequest")
        fake_em_http_request.stub( :get ).with({:head=>{'User-Agent'=>Settings::Embedly.user_agent}}).and_return(
          mock_model("FakeEMHttpResponse", :error => false, :response_header => mock_model("FakeResponseHeader", :status => 200), :response => embedly_hash.to_json )
          )
        EventMachine::HttpRequest.stub( :new ).and_return( fake_em_http_request )
        
        #expect caching#
        GT::UrlVideoDetector.should_receive(:add_link_to_video_processing_cache).with(@url, embedly_hash.to_json, :fake_client)
        
        GT::UrlVideoDetector.examine_url_for_video(@url, true, :fake_client).should == [{:embedly_hash => embedly_hash}]
      end
    
      it "should save nil to cache on 404"  do
        embedly_hash = {"some" => "thing", "fake" => true}
        
        fake_em_http_request = mock_model("FakeEMHttpRequest")
        fake_em_http_request.stub( :get ).with({:head=>{'User-Agent'=>Settings::Embedly.user_agent}}).and_return(
          mock_model("FakeEMHttpResponse", :error => false, :response_header => mock_model("FakeResponseHeader", :status => 404) )
          )
        EventMachine::HttpRequest.stub( :new ).and_return( fake_em_http_request )
        
        #expect nil caching#
        GT::UrlVideoDetector.should_receive(:add_link_to_video_processing_cache).with(@url, nil, :fake_client)
        
        GT::UrlVideoDetector.examine_url_for_video(@url, true, :fake_client).should == nil
      end
    end
    
  end
  
end
