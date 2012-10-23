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
      resp = {
        "awesm_urls" => [{"service"=>"manual", "parent"=>nil, "original_url"=>"http://henrysztul.info", "redirect_url"=>"http://henrysztul.info?frame_id=#{@frame.id}&awesm=shl.by_4", "awesm_id"=>"shl.by_4", "awesm_url"=>"http://shl.by/4", "user_id"=>nil, "path"=>"4", "channel"=>"manual", "domain"=>"shl.by"}]}
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
    
end