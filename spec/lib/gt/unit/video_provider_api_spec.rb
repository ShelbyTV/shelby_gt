require 'spec_helper'
require 'youtube_it'
require 'video_provider_api'

describe GT::VideoProviderApi do

  context "youtube" do
    it "should return a persisted video" do
      fake_em_http_request = mock_model("FakeEMHttpRequest")
      fake_em_http_request.stub(:get).and_return(
          mock_model("FakeEMHttpResonse", :error => false,
                          :response_header => mock_model("FakeResponseHeader", :status => 200), :response => open(File.expand_path("../testhtmlfiles/youtubegdata.html", __FILE__))))
      EventMachine::HttpRequest.stub(:new).and_return(fake_em_http_request)
      vid = GT::VideoProviderApi.examine_url_for_youtube_video("fakeid")
      vid.provider_id.should == "LTMyiQg7x6w"
    end
  end
end


      


