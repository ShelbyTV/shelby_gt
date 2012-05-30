require 'spec_helper'
require 'deeplink_parser'

describe GT::DeeplinkParser do
  before(:all) do

    @deeplink = "http://www.youtube.com/embed/lMBMcMf85ow?version=3&rel=1&fs=1&showsearch=0&showinfo=1&iv_load_policy=1&wmode=transparent"

    @urlhaslink = "http://www.testdeep.com/haslink.html"
    @urlnolink = "http://www.testdeep.com/hasnolink.html"
    @urlbadlinks = "http://www.testdeep.com/hasbadlinks.html"

    @blacklisted = "instagr.am/photos"
      
  end


  context "parse_deep" do
    it "should parse deep corecctly" do
      fake_em_http_request = mock_model("FakeEMHttpRequest")
      fake_em_http_request.stub(:get).and_return(
          mock_model("FakeEMHttpResonse", :error => false,
            :response_header => mock_model("FakeResponseHeader", :status => 200), :response => open(File.expand_path("../testdeepfiles/rant.html",__FILE__))))
        EventMachine::HttpRequest.stub(:new).and_return(fake_em_http_request)
      GT::DeeplinkParser.find_deep_link(@urlhaslink).should == [[@deeplink], true]
      
    end

    it "should not return bad url" do
      fake_em_http_request = mock_model("FakeEMHttpRequest")
      fake_em_http_request.stub(:get).and_return(
          mock_model("FakeEMHttpResonse", :error => false,
            :response_header => mock_model("FakeResponseHeader", :status => 200), :response => open(File.expand_path("../testdeepfiles/badlinks.html",__FILE__))))
        EventMachine::HttpRequest.stub(:new).and_return(fake_em_http_request)
      GT::DeeplinkParser.find_deep_link(@urlbadlinks).should == [[], true]
    end    


    it "should not find something" do
      fake_em_http_request = mock_model("FakeEMHttpRequest")
      fake_em_http_request.stub(:get).and_return(
          mock_model("FakeEMHttpResonse", :error => false,
            :response_header => mock_model("FakeResponseHeader", :status => 200), :response => open(File.expand_path("../testdeepfiles/google.html", __FILE__))))
        EventMachine::HttpRequest.stub(:new).and_return(fake_em_http_request)
      GT::DeeplinkParser.find_deep_link(@urlnolink).should == [[], true]
    end


    it "should be blacklisted" do
      GT::DeeplinkParser.find_deep_link(@blacklisted).should == [[],false]
    end
  end
end
      
    


