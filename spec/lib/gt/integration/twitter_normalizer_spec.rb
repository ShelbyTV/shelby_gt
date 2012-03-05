require 'spec_helper'
require 'twitter_normalizer'
require 'framer'

# UNIT test
describe GT::TwitterNormalizer do
  
  before(:each) do
    @video = Video.create
    @frame_creator = User.create( :nickname => "#{rand.to_s}-#{Time.now.to_f}" )
    @message = Message.new
  
  
    @roll_creator = User.create( :nickname => "#{rand.to_s}-#{Time.now.to_f}" )
    @roll = Roll.new( :title => "title" )
    @roll.creator = @roll_creator
    @roll.save
  end
  
  context "integration with GT::Framer" do
  
    it "should create Frame with normalized tweet Message" do
      m = GT::TwitterNormalizer.normalize_tweet(TwitterData.no_video_hash)
    
      res = GT::Framer.create_frame!(
        :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
        :creator => @frame_creator,
        :video => @video,
        :message => m,
        :roll => @roll
        )
    
      res[:frame].conversation.messages.size.should == 1
      res[:frame].conversation.messages[0].should == m
    
      res[:frame].conversation.messages[0].origin_network.should == "twitter"
      res[:frame].conversation.messages[0].origin_id.should == "176051240076185600"
      res[:frame].conversation.messages[0].origin_user_id.should == "20096495"

      res[:frame].conversation.messages[0].nickname.should == "laurenwick"
      res[:frame].conversation.messages[0].realname.should == "Lauren Appelwick"
      res[:frame].conversation.messages[0].user_image_url.should == "http://a3.twimg.com/profile_images/1778667511/LAxc_normal.jpg"

      res[:frame].conversation.messages[0].text.should == "There's a lingering smell of fart... (@ Anthropologie) http://t.co/ibAVw8pu"    
    end
  
  end # /context GT::TwitterNormalizer + GT::Framer
  
  
end