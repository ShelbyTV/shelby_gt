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
    m.public.should == true
    
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
  
  it "should work on this data (which we saw fail in production b/c it didn't have update text)" do
    job_details = {:provider_type=>"facebook", :provider_user_id=>"100000700057560", :facebook_status_update=>{"id"=>"100001011681932_275112459239498", "from"=>{"name"=>"Cecilia Cabral", "id"=>"100001011681932"}, "story"=>"Cecilia Cabral shared a link.", "story_tags"=>{"0"=>[{"id"=>100001011681932, "name"=>"Cecilia Cabral", "offset"=>0, "length"=>14, "type"=>"user"}]}, "picture"=>"https://s-external.ak.fbcdn.net/safe_image.php?d=AQBdM3RxpZwlZB-F&w=130&h=130&url=http%3A%2F%2Fi3.ytimg.com%2Fvi%2FjSp-b-0dRSQ%2Fhqdefault.jpg", "link"=>"http://www.youtube.com/watch?v=jSp-b-0dRSQ&feature=share", "source"=>"http://www.youtube.com/v/jSp-b-0dRSQ?version=3&autohide=1&autoplay=1", "name"=>"romeo santo llevame contigo 2011", "caption"=>"www.youtube.com", "icon"=>"https://s-static.ak.facebook.com/rsrc.php/v1/yj/r/v2OnaTyTQZE.gif", "actions"=>[{"name"=>"Comment", "link"=>"http://www.facebook.com/100001011681932/posts/275112459239498"}, {"name"=>"Like", "link"=>"http://www.facebook.com/100001011681932/posts/275112459239498"}], "type"=>"video", "application"=>{"name"=>"Share_bookmarklet", "id"=>"5085647995"}, "created_time"=>"2012-04-04T19:22:58+0000", "updated_time"=>"2012-04-04T19:22:58+0000", "likes"=>{"data"=>[{"name"=>"Dianelva Gutierrez", "id"=>"100001055096384"}], "count"=>1}, "comments"=>{"count"=>0}}, :has_status=>true, :url=>"http://www.youtube.com/v/jSp-b-0dRSQ?version=3&autohide=1&autoplay=1"}
    
    m = GT::FacebookNormalizer.normalize_post(job_details[:facebook_status_update])
    
    m.should_not == nil
  end
  
end