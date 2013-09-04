require 'spec_helper'
require 'youtube_it'
require 'video_provider_api'

describe GT::VideoProviderApi do

  context "examine_url_for_youtube_video" do
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

  context "get_video_info" do
    it "should call the correct youtube api route" do
      HTTParty.should_receive(:get).with("http://gdata.youtube.com/feeds/api/videos/12345")

      GT::VideoProviderApi.get_video_info("youtube", "12345")
    end

    it "should call the correct vimeo api route" do
      HTTParty.should_receive(:get).with("http://vimeo.com/api/oembed.json?url=http%3A//vimeo.com/12345")

      GT::VideoProviderApi.get_video_info("vimeo", "12345")
    end

    it "should call the correct dailymotion api route" do
      HTTParty.should_receive(:get).with("https://api.dailymotion.com/video/12345?fields=allow_embed%2Cstatus")

      GT::VideoProviderApi.get_video_info("dailymotion", "12345")
    end
  end
end





