require 'spec_helper'

require 'social_poster'

# INTEGRATION test (b/c it relies on and implicitly tests social_poster lib)
describe GT::SocialPoster do
  
  context "posting to twitter" do
    before(:all) do
      @from_user = Factory.create(:user)
      @comment = "how much would a wood chuck chuck..."
      @conversation = Factory.create(:conversation, :messages => [Factory.create(:message, :text => @comment)])
      @frame = Factory.create(:frame, :creator_id => @from_user.id, :conversation_id => @conversation.id)
    end
    
    it "should return true if user has twitter acct and tweet is sent" do
      tweet = GT::SocialPoster.post_to_twitter(@from_user, @comment)
      tweet.should eq(true)
    end
    
    it "should return false if a parameter isn't given" do
      tweet = GT::SocialPoster.post_to_twitter(nil, @comment)
      tweet.should eq(false)
    end

    it "should return false if user has no twitter acct" do
      @from_user.authentications.first.provider = 'not_twitter'
      @from_user.save
      
      tweet = GT::SocialPoster.post_to_twitter(@from_user, @comment)
      tweet.should eq(nil)
    end 
  end
  
  context "posting to facebook" do
    before(:all) do
      @from_user = Factory.create(:user)
      @from_user.authentications.first.provider = "facebook"; @from_user.save
      @comment = "how much would a wood chuck chuck..."
      @conversation = Factory.create(:conversation, :messages => [Factory.create(:message, :text => @comment)])
      @frame = Factory.create(:frame, :creator_id => @from_user.id, :conversation_id => @conversation.id)
    end
    
    it "should return true if user has facebook acct and post is sent" do
      post = GT::SocialPoster.post_to_facebook(@from_user, @comment, @frame)
      post.should eq(true)
    end
    
    it "should return false if a parameter isn't given" do
      post = GT::SocialPoster.post_to_facebook(nil, @comment, @frame)
      post.should eq(false)
    end

    it "should return false if user has no facebook acct" do
      @from_user.authentications.first.provider = 'bookface'
      @from_user.save
      
      post = GT::SocialPoster.post_to_facebook(@from_user, @comment, nil)
      post.should eq(nil)
    end
  end

  context "posting to tumblr" do
    #we need an iframe player for gt before we can post to tumblr!
    it 'should post to tumblr'
  end
  
  context "send via email" do
    before(:all) do
      @from_user = Factory.create(:user)
      @from_user.primary_email = "my@email.com"; @from_user.save
      @comment = "how much would a wood chuck chuck..."
      video = Factory.create(:video, :thumbnail_url => "http://url.com/123.jpg")
      @frame = Factory.create(:frame, :creator_id => @from_user.id, :video_id => video.id)
    end
    
    it "should send email of a frame and return a Mail::Message" do
      to_user = "some_other@email.com"
      email = GT::SocialPoster.post_to_email(@from_user, to_user, @comment, @frame)
      
      email.class.should eq(Mail::Message)
      email.from.should  eq([@from_user.primary_email])
      email.to.should  eq([to_user])
    end
    
    it "should send email of a roll and return a Mail::Message"
    
    
  end
end