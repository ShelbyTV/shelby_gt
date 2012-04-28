require 'spec_helper'
require 'link_shortner'

describe GT::LinkShortner do

  context "get or create short links for frames" do
    before(:each) do
      @frame = Factory.create(:frame)
    end
    
    it "should return a short link that we have already" do
      @frame.short_links[:twitter] = "http://i.ro.ck"; @frame.save
      r = GT::LinkShortner.get_or_create_shortlink(@frame, ["twitter"])
      r.should eq(@frame.short_links)
    end
    
    it "should get a new short link if it doesnt exist" do
      resp = {"awesm_urls" => [{"service"=>"twitter", "parent"=>nil, "original_url"=>"http://henrysztul.info", "redirect_url"=>"http://henrysztul.info?awesm=shl.by_4", "awesm_id"=>"shl.by_4", "awesm_url"=>"http://shl.by/4", "user_id"=>nil, "path"=>"4", "channel"=>"twitter", "domain"=>"shl.by"}]}
      Awesm::Url.stub(:batch).and_return([200, resp])
      r = GT::LinkShortner.get_or_create_shortlink(@frame, ["twitter"])
      r["twitter"].should eq(resp["awesm_urls"].first["awesm_url"])
    end
    
    it "should return error if we dont pass an array" do
      lambda { GT::LinkShortner.get_or_create_shortlink("test") }.should raise_error(ArgumentError)
    end
    
  end
  
  context "get or create short links for rolls" do
    before(:each) do
      @roll = Factory.create(:roll, :creator => Factory.create(:user))
    end
    
    it "should return a short link that we have already" do
      @roll.short_links[:twitter] = "http://i.ro.ck"; @roll.save
      r = GT::LinkShortner.get_or_create_shortlink(@roll, ["twitter"])
      r.should eq(@roll.short_links)
    end
    
    it "should get a new short link if it doesnt exist" do
      resp = {"awesm_urls" => [{"service"=>"twitter", "parent"=>nil, "original_url"=>"http://henrysztul.info", "redirect_url"=>"http://henrysztul.info?awesm=shl.by_4", "awesm_id"=>"shl.by_4", "awesm_url"=>"http://shl.by/4", "user_id"=>nil, "path"=>"4", "channel"=>"twitter", "domain"=>"shl.by"}]}
      Awesm::Url.stub(:batch).and_return([200, resp])
      r = GT::LinkShortner.get_or_create_shortlink(@roll, ["twitter"])
      r["twitter"].should eq(resp["awesm_urls"].first["awesm_url"])
    end
    
    it "should return error if we dont pass an array" do
      lambda { GT::LinkShortner.get_or_create_shortlink(@roll, "test") }.should raise_error(ArgumentError)
      lambda { GT::LinkShortner.get_or_create_shortlink(@roll) }.should raise_error(ArgumentError)
      lambda { GT::LinkShortner.get_or_create_shortlink(Factory.create(:user), "test") }.should raise_error(ArgumentError)
    end
  end
    
end