require 'spec_helper'
require 'deeplink_parser'

describe GT::DeeplinkParser do
  before(:all) do

    @ytdeeplink = "http://www.youtube.com/watch?v=lMBMcMf85ow"
    @vmdeeplink = "http://www.vimeo.com/2601853"

    @urlhasytlink = "http://www.testdeep.com/haslink.html"
    @urlhasvmlink = "http://www.ifyoumakeit.com/video/cheap=girls/parking-lot/"
    @urlnolink = "http://www.testdeep.com/hasnolink.html"
    @urlbadlinks = "http://www.testdeep.com/hasbadlinks.html"

    @blacklisted = "instagr.am/photos"
      
  end


  context "parse_deep" do
    it "should parse yt deep corecctly" do
      fake_em_http_request = mock_model("FakeEMHttpRequest")
      fake_em_http_request.stub(:get).and_return(
          mock_model("FakeEMHttpResonse", :error => false,
            :response_header => mock_model("FakeResponseHeader", :status => 200), :response => open(File.expand_path("../testhtmlfiles/rant.html",__FILE__))))
        EventMachine::HttpRequest.stub(:new).and_return(fake_em_http_request)
      GT::DeeplinkParser.find_deep_link(@urlhasytlink).should == {:urls => [@ytdeeplink], :to_cache => true}
      
    end

    it "should parse vm deep correctly" do
      fake_em_http_request = mock_model("FakeEMHttpRequest")
      fake_em_http_request.stub(:get).and_return(
          mock_model("FakeEMHttpResonse", :error => false,
            :response_header => mock_model("FakeResponseHeader", :status => 200), :response => open(File.expand_path("../testhtmlfiles/vimeodeeptest.html",__FILE__))))
        EventMachine::HttpRequest.stub(:new).and_return(fake_em_http_request)
      GT::DeeplinkParser.find_deep_link(@urlhasvmlink).should == {:urls => [@vmdeeplink], :to_cache => true}
    end




    it "should not return bad url" do
      fake_em_http_request = mock_model("FakeEMHttpRequest")
      fake_em_http_request.stub(:get).and_return(
          mock_model("FakeEMHttpResonse", :error => false,
            :response_header => mock_model("FakeResponseHeader", :status => 200), :response => open(File.expand_path("../testhtmlfiles/badlinks.html",__FILE__))))
        EventMachine::HttpRequest.stub(:new).and_return(fake_em_http_request)
      GT::DeeplinkParser.find_deep_link(@urlbadlinks).should == {:urls => [], :to_cache => true}
    end    


    it "should not find something" do
      fake_em_http_request = mock_model("FakeEMHttpRequest")
      fake_em_http_request.stub(:get).and_return(
          mock_model("FakeEMHttpResonse", :error => false,
            :response_header => mock_model("FakeResponseHeader", :status => 200), :response => open(File.expand_path("../testhtmlfiles/google.html", __FILE__))))
        EventMachine::HttpRequest.stub(:new).and_return(fake_em_http_request)
      GT::DeeplinkParser.find_deep_link(@urlnolink).should == {:urls => [], :to_cache => true}
    end


    it "should be blacklisted" do
      GT::DeeplinkParser.find_deep_link(@blacklisted).should == {:urls => [], :to_cache => false}
    end
  end
end
      
    


