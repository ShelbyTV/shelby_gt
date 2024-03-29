require 'spec_helper'
require 'link_shortener'

describe GT::LinkShortener do

  context "get or create short links for frames" do
    before(:each) do
      @frame = Factory.create(:frame)
    end

    it "should return a short link that we have already" do
      @frame.short_links[:twitter] = "http://i.ro.ck"; @frame.save
      Awesm::Url.should_receive(:batch).exactly(0).times
      r = GT::LinkShortener.get_or_create_shortlinks(@frame, "twitter")
      r.should eq(@frame.short_links)
    end

    it "should get a new short link if it doesnt exist for twitter" do
      resp = {"awesm_urls" => [{"service"=>"twitter", "parent"=>nil, "original_url"=>"http://henrysztul.info", "redirect_url"=>"http://henrysztul.info?awesm=shl.by_4", "awesm_id"=>"shl.by_4", "awesm_url"=>"http://shl.by/4", "user_id"=>nil, "path"=>"4", "channel"=>"twitter", "domain"=>"shl.by"}]}
      Awesm::Url.stub(:batch).and_return([200, resp])
      r = GT::LinkShortener.get_or_create_shortlinks(@frame, "twitter")
      r["twitter"].should eq(resp["awesm_urls"].first["awesm_url"])
    end

    it "should get a new short link if it doesnt exist for facebook" do
      resp = {"awesm_urls" => [{"service"=>"facebook", "parent"=>nil, "original_url"=>"http://henrysztul.info", "redirect_url"=>"http://henrysztul.info?awesm=shl.by_4", "awesm_id"=>"shl.by_4", "awesm_url"=>"http://shl.by/4", "user_id"=>nil, "path"=>"4", "channel"=>"facebook-post", "domain"=>"shl.by"}]}
      Awesm::Url.stub(:batch).and_return([200, resp])
      r = GT::LinkShortener.get_or_create_shortlinks(@frame, "facebook")

      r["facebook"].should eq(resp["awesm_urls"].first["awesm_url"])
    end

    it "should get links for twitter and facebook simultaneously" do
      resp = {
        "awesm_urls" => [
          {"service"=>"facebook", "parent"=>nil, "original_url"=>"http://henrysztul.info", "redirect_url"=>"http://henrysztul.info?awesm=shl.by_4", "awesm_id"=>"shl.by_4", "awesm_url"=>"http://shl.by/4", "user_id"=>nil, "path"=>"4", "channel"=>"facebook-post", "domain"=>"shl.by"},
          {"service"=>"twitter", "parent"=>nil, "original_url"=>"http://henrysztul.info", "redirect_url"=>"http://henrysztul.info?awesm=shl.by_4", "awesm_id"=>"shl.by_4", "awesm_url"=>"http://shl.by/4", "user_id"=>nil, "path"=>"4", "channel"=>"twitter", "domain"=>"shl.by"}]}
      Awesm::Url.stub(:batch).and_return([200, resp])
      r = GT::LinkShortener.get_or_create_shortlinks(@frame, "twitter,facebook")

      r["facebook"].should eq(resp["awesm_urls"][0]["awesm_url"])
      r["twitter"].should eq(resp["awesm_urls"][1]["awesm_url"])
    end

    it "should get a link for a manually created frame shortlink and have correct url params" do
      video_permalink = @frame.video_page_permalink()
      resp = {
        "awesm_urls" => [{"service"=>"manual", "parent"=>nil, "original_url"=>video_permalink, "redirect_url"=>"#{video_permalink}&awesm=shl.by_4", "awesm_id"=>"shl.by_4", "awesm_url"=>"http://shl.by/4", "user_id"=>nil, "path"=>"4", "channel"=>"manual", "domain"=>"shl.by"}]}
      Awesm::Url.stub(:batch).and_return([200, resp])
      r = GT::LinkShortener.get_or_create_shortlinks(@frame, "manual")
      r["manual"].should eq(resp["awesm_urls"][0]["awesm_url"])
    end

    it "should return error if we dont pass an array" do
      lambda { GT::LinkShortener.get_or_create_shortlinks("test") }.should raise_error(ArgumentError)
    end

  end

  context "get or create short links for rolls" do
    before(:each) do
      @roll = Factory.create(:roll, :creator => Factory.create(:user))
    end

    it "should return a short link that we have already" do
      @roll.short_links[:twitter] = "http://i.ro.ck"; @roll.save
      Awesm::Url.should_receive(:batch).exactly(0).times
      r = GT::LinkShortener.get_or_create_shortlinks(@roll, "twitter")
      r.should eq(@roll.short_links)
    end

    it "should get a new short link if it doesnt exist" do
      resp = {"awesm_urls" => [{"service"=>"twitter", "parent"=>nil, "original_url"=>"http://henrysztul.info", "redirect_url"=>"http://henrysztul.info?awesm=shl.by_4", "awesm_id"=>"shl.by_4", "awesm_url"=>"http://shl.by/4", "user_id"=>nil, "path"=>"4", "channel"=>"twitter", "domain"=>"shl.by"}]}
      Awesm::Url.stub(:batch).and_return([200, resp])
      r = GT::LinkShortener.get_or_create_shortlinks(@roll, "twitter")
      r["twitter"].should eq(resp["awesm_urls"].first["awesm_url"])
    end

    it "should return error if we dont pass an array" do
      lambda { GT::LinkShortener.get_or_create_shortlinks(@roll, ["test"]) }.should raise_error(ArgumentError)
      lambda { GT::LinkShortener.get_or_create_shortlinks(@roll) }.should raise_error(ArgumentError)
      lambda { GT::LinkShortener.get_or_create_shortlinks(Factory.create(:user), ["test"]) }.should raise_error(ArgumentError)
    end
  end

  context "get or create short links for videos" do
    before(:each) do
      @video = Factory.create(:video)
    end

    it "should not return error for video as linkable argument" do
      Awesm::Url.stub(:batch).and_return([404, nil])
      lambda { GT::LinkShortener.get_or_create_shortlinks(@video, "twitter") }.should_not raise_error
    end

    it "should return a short link that we have already" do
      @video.short_links[:twitter] = "http://i.ro.ck"; @video.save
      Awesm::Url.should_receive(:batch).exactly(0).times
      r = GT::LinkShortener.get_or_create_shortlinks(@video, "twitter")
      r.should eq(@video.short_links)
    end

    it "should get a new short link if it doesnt exist" do
      resp = {"awesm_urls" => [{"service"=>"twitter", "parent"=>nil, "original_url"=>"http://henrysztul.info", "redirect_url"=>"http://henrysztul.info?awesm=shl.by_4", "awesm_id"=>"shl.by_4", "awesm_url"=>"http://shl.by/4", "user_id"=>nil, "path"=>"4", "channel"=>"twitter", "domain"=>"shl.by"}]}
      Awesm::Url.stub(:batch).and_return([200, resp])
      r = GT::LinkShortener.get_or_create_shortlinks(@video, "twitter")
      r["twitter"].should eq(resp["awesm_urls"].first["awesm_url"])
    end

    it "should return error if we dont pass an array" do
      lambda { GT::LinkShortener.get_or_create_shortlinks(@video, ["test"]) }.should raise_error(ArgumentError)
      lambda { GT::LinkShortener.get_or_create_shortlinks(@video) }.should raise_error(ArgumentError)
    end
  end


  context "get or create short links for dashboard entries to channels" do
    before(:each) do
      @frame = Factory.create(:frame)
      @dashboard_entry = Factory.create(:dashboard_entry, :frame => @frame)
    end

    it "should not return error for dashboard entry as linkable argument" do
      Awesm::Url.stub(:batch).and_return([404, nil])
      lambda { GT::LinkShortener.get_or_create_shortlinks(@dashboard_entry, "twitter") }.should_not raise_error
    end

    it "should return a short link that we have already" do
      @dashboard_entry.short_links[:twitter] = "http://i.ro.ck";
      Awesm::Url.should_receive(:batch).exactly(0).times
      r = GT::LinkShortener.get_or_create_shortlinks(@dashboard_entry, "twitter")
      r.should eq(@dashboard_entry.short_links)
    end

    it "should get a new short link if it doesnt exist" do
      resp = {"awesm_urls" => [{"service"=>"twitter", "parent"=>nil, "original_url"=>"http://henrysztul.info", "redirect_url"=>"http://henrysztul.info?awesm=shl.by_4", "awesm_id"=>"shl.by_4", "awesm_url"=>"http://shl.by/4", "user_id"=>nil, "path"=>"4", "channel"=>"twitter", "domain"=>"shl.by"}]}
      Awesm::Url.should_receive(:batch).with({
        :url => @dashboard_entry.permalink,
        :channel => "twitter",
        :key => Settings::Awesm.api_key,
        :tool => Settings::Awesm.tool_key
      }).and_return([200, resp])
      r = GT::LinkShortener.get_or_create_shortlinks(@dashboard_entry, "twitter")
      r["twitter"].should eq(resp["awesm_urls"].first["awesm_url"])
    end

    it "should return error if we dont pass a destination string" do
      lambda { GT::LinkShortener.get_or_create_shortlinks(@dashboard_entry, ["test"]) }.should raise_error(ArgumentError)
      lambda { GT::LinkShortener.get_or_create_shortlinks(@dashboard_entry) }.should raise_error(ArgumentError)
    end

  end
end