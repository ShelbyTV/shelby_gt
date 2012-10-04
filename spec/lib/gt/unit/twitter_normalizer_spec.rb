require 'spec_helper'
require 'twitter_normalizer'

# UNIT test
describe GT::TwitterNormalizer do
  
  it "should normalize all necessary tweet metadata for Message" do
    m = GT::TwitterNormalizer.normalize_tweet(TwitterData.no_video_hash)
    
    m.origin_network.should == "twitter"
    m.origin_id.should == "10765432100123456789"
    m.origin_user_id.should == "20096495"
    m.public.should == true
    
    m.nickname.should == "laurenwick"
    m.realname.should == "Lauren Appelwick"
    m.user_image_url.should == "http://a3.twimg.com/profile_images/1778667511/LAxc_normal.jpg"
    
    m.text.should == "There's a lingering smell of fart... (@ Anthropologie) http://t.co/ibAVw8pu"
  end
  
  it "should use id_str for tweet and user" do
    h = TwitterData.no_video_hash
    h['id'] = nil
    h['user']['id'] = nil
    m = GT::TwitterNormalizer.normalize_tweet(h)
    
    m.origin_id.should == "10765432100123456789"
    m.origin_user_id.should == "20096495"
  end
  
  it "should not barf on empty or bad input" do
    m = GT::TwitterNormalizer.normalize_tweet({})
    m.should == nil
    
    lambda { GT::TwitterNormalizer.normalize_tweet(nil) }.should raise_error(ArgumentError)
    lambda { GT::TwitterNormalizer.normalize_tweet(TwitterData.no_video_json) }.should raise_error(ArgumentError)
  end
  
end