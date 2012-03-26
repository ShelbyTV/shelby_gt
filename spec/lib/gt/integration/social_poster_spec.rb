require 'spec_helper'

require 'social_poster'

# INTEGRATION test (b/c it relies on and implicitly tests social_posting lib)
describe GT::SocialPoster do

  before(:all) do
    @from_user = Factory.create(:user)
    @comment = "how much would a wood chuck chuck..."
    @conversation = Factory.create(:conversation, :messages => [Factory.create(:message, :text => @comment)])
    @frame = Factory.create(:frame, :creator_id => @from_user.id, :conversation_id => @conversation.id)
  end
  
  context "posting to twitter" do
    it "should return true if user has twitter acct and tweet is sent" do
      tweet = GT::SocialPoster.post_to_twitter(@from_user, @comment, @frame)
      tweet.should eq(true)
    end
    
    it "should return false if a parameter isn't given" do
      tweet1 = GT::SocialPoster.post_to_twitter(nil, @comment, @frame)
      tweet1.should eq(false)
      
      tweet2 = GT::SocialPoster.post_to_twitter(@from_user, nil, @frame)
      tweet1.should eq(false)
      
      tweet3 = GT::SocialPoster.post_to_twitter(@from_user, @comment, nil)
      tweet3.should eq(false)
    end

    it "should return false if user has no twitter acct" do
      fb_user = Factory.create(:user)
      fb_user.authentications.first.provider = 'not_twitter'
      fb_user.save
      
      tweet = GT::SocialPoster.post_to_twitter(@from_user, @comment, nil)
      tweet.should eq(false)
    end 
  end

  context "posting to tumblr" do
    #we need an iframe player for gt before we can post to tumblr!
  end
  
  context "posting to facebook" do
    
  end
end