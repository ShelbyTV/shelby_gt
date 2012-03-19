# encoding: UTF-8

require 'spec_helper'
require 'facebook_normalizer'

# UNIT test
describe GT::FacebookNormalizer do
  
  it "should normalize all necessary fb post metadata for Message" do
    m = GT::FacebookNormalizer.normalize_post(FacebookData.with_video_hash)
    
    m.origin_network.should == "facebook"
    m.origin_id.should == "1850281655_372627419426123"
    m.origin_user_id.should == "1850281655"
    m.public.should == false
    
    m.nickname.should == "Melih Ang"
    m.realname.should == "Melih Ang"
    m.user_image_url.should == "http://graph.facebook.com/1850281655/picture"
    
    m.text.should == "Bulgarian-born DJ and producer Emmo has a Ph.D. degree in Microbiology and did his postdoctoral training in Biochemistry, Molecular Biology, and Human Geneti..."
  end
  
  it "should not barf on empty or bad input" do
    m = GT::FacebookNormalizer.normalize_post({})
    m.should == nil
    
    lambda { GT::FacebookNormalizer.normalize_post(nil) }.should raise_error(ArgumentError)
    lambda { GT::FacebookNormalizer.normalize_post(FacebookData.with_video_json) }.should raise_error(ArgumentError)
  end
  
end