# encoding: UTF-8

require 'spec_helper'
require 'tumblr_normalizer'

# UNIT test
describe GT::TumblrNormalizer do
  
  it "should normalize all necessary tumblr post metadata for Message" do
    m = GT::TumblrNormalizer.normalize_post(TumblrData.with_video_hash)
    
    m.origin_network.should == "tumblr"
    m.origin_id.should == "19628372236"
    m.origin_user_id.should == "dangsallydang"
    m.public.should == true
    
    m.nickname.should == "dangsallydang"
    m.realname.should == "dangsallydang"
    m.user_image_url.should == "http://api.tumblr.com/v2/blog/dangsallydang.tumblr.com/avatar/512"
    
    # Text is the sanitized/cleaned version of the caption
    m.text.should == "anthonyjoachim: \n \n MURDER INC. \n GIRRRRRRL YOUR STARE THOSE EYES  \n LOVE IT WHEN YOU LOOK AT ME BABY  \n YOUR LIPS YUR SMILE LUV IT WHEN YOU KISS ME BABY  \n YOUR HIPS THOSE THIGHS  LUV IT WHEN YOU THUG ME BABY  \n AND I CANT DENY I , LOVE IT WWHEN IM WITCHU BABY  \n \n AWWW YEEE"
  end
  
  it "should correctly parse user_image_url with . blog name" do
    hash = TumblrData.with_video_hash
    hash['blog_name'] = "spinosa"
    m = GT::TumblrNormalizer.normalize_post(hash)
    m.user_image_url.should == "http://api.tumblr.com/v2/blog/spinosa.tumblr.com/avatar/512"
  end
  
  it "should correctly parse user_image_url without . in blog name" do
    hash = TumblrData.with_video_hash
    hash['blog_name'] = "spinosa.tv"
    m = GT::TumblrNormalizer.normalize_post(hash)
    m.user_image_url.should == "http://api.tumblr.com/v2/blog/spinosa.tv/avatar/512"
  end
  
  it "should not barf on empty or bad input" do
    m = GT::TumblrNormalizer.normalize_post({})
    m.should == nil
    
    lambda { GT::TumblrNormalizer.normalize_post(nil) }.should raise_error(ArgumentError)
    lambda { GT::TumblrNormalizer.normalize_post(TumblrData.with_video_json) }.should raise_error(ArgumentError)
  end
  
end