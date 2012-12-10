require 'spec_helper'
require 'discussion_roll_utils'

class DiscussionRollTester
  include GT::DiscussionRollUtils
end

# UNIT test
describe GT::DiscussionRollUtils do
  before(:all) do
    @roll = Factory.create(:roll)
    @user = Factory.create(:user)
    @tester = DiscussionRollTester.new
  end
  
  context "find_videos_linked_in_text" do
    #this fully tests videos_from_url_array
    
    it "should return empty array when there are no urls" do
      vids = @tester.find_videos_linked_in_text("no urls in here")
      vids.should == []
    end
    
    it "should return empty array when there are no video urls" do
      vids = @tester.find_videos_linked_in_text("not a video url http://google.com")
      vids.should == []
    end
    
    it "should return a single video" do
      v1 = Factory.create(:video)
      v1_url = "http://site.com/video1"
      GT::VideoManager.should_receive(:get_or_create_videos_for_url).with(v1_url).and_return({:videos => [v1]})
      
      vids = @tester.find_videos_linked_in_text("#{v1_url} and thats all")
      vids.size.should == 1
      vids.should == [v1]
    end
    
    it "should return multiple videos" do
      v1 = Factory.create(:video)
      v1_url = "http://site.com/video1"
      v2 = Factory.create(:video)
      v2_url = "https://site.com/video2"
      #make sure v1, v2 are returned
      GT::VideoManager.should_receive(:get_or_create_videos_for_url).with(v1_url).and_return({:videos => [v1]})
      GT::VideoManager.should_receive(:get_or_create_videos_for_url).with(v2_url).and_return({:videos => [v2]})
      
      vids = @tester.find_videos_linked_in_text("first video is #{v1_url} second video is #{v2_url}")
      vids.size.should == 2
      vids.should == [v1, v2]
    end
  end
  
  context "token" do
    it "should produce a valid token" do
      token = GT::DiscussionRollUtils.encrypt_roll_user_identification(@roll, "dan@shelby.tv")
      @tester.valid_token?(token).should == true
    end
    
    it "should return the roll's id from the token" do
      token = GT::DiscussionRollUtils.encrypt_roll_user_identification(@roll, "dan@shelby.tv")
      @tester.roll_identifier_from_token(token).should == @roll.id.to_s
    end
    
    it "should return user email from the token" do
      token = GT::DiscussionRollUtils.encrypt_roll_user_identification(@roll, "dan@shelby.tv")
      @tester.user_identifier_from_token(token).should == "dan@shelby.tv"
    end
    
    it "should return user id from token" do
      token = GT::DiscussionRollUtils.encrypt_roll_user_identification(@roll, @user.id)
      @tester.user_identifier_from_token(token).should == @user.id.to_s
    end
    
    it "should return email_from_token" do
      token = GT::DiscussionRollUtils.encrypt_roll_user_identification(@roll, "dan spinosa <dan@shelby.tv>")
      @tester.email_from_token(token).name.should == "dan spinosa"
      @tester.email_from_token(token).address.should == "dan@shelby.tv"
      
      token = GT::DiscussionRollUtils.encrypt_roll_user_identification(@roll, "dan@shelby.tv")
      @tester.email_from_token(token).name.should == nil
      @tester.email_from_token(token).address.should == "dan@shelby.tv"
    end
    
    it "should return user_from_token" do
      token = GT::DiscussionRollUtils.encrypt_roll_user_identification(@roll, @user.id)
      @tester.user_from_token(token).should == @user
    end
    
    it "should return nil user_from_token" do
      token = GT::DiscussionRollUtils.encrypt_roll_user_identification(@roll, "spinosa@shelby.tv")
      @tester.user_from_token(token).should == nil
    end
    
    it "should determine token_valid_for_discussion_roll?" do
      token = GT::DiscussionRollUtils.encrypt_roll_user_identification(@roll, @user.id)
      @tester.token_valid_for_discussion_roll?(token, @roll).should == true
      @tester.token_valid_for_discussion_roll?("blah", @roll).should == false
      @tester.token_valid_for_discussion_roll?("", @roll).should == false
      @tester.token_valid_for_discussion_roll?(nil, @roll).should == false
      @tester.token_valid_for_discussion_roll?(token, Factory.create(:roll)).should == false
    end
  end
  
  context "convert_participants" do
    it "should downcase email address" do
      @tester.convert_participants("DAN@Shelby.tv;reece@SHELBY.tv").should == ["dan@shelby.tv","reece@shelby.tv"]
    end
    
    it "should find users for email addresses" do
      @tester.convert_participants(@user.primary_email).should == [@user.id.to_s]
    end
    
    it "should return an array of unique users for non-user" do
      @tester.convert_participants("DAN@Shelby.tv,dan@SHELBY.tv").should == ["dan@shelby.tv"]
    end
    
    it "should return an array of unique users for real user bson id" do
      @tester.convert_participants("#{@user.primary_email},#{@user.primary_email}").should == [@user.id.to_s]
    end
    
    it "should find user based on nickname" do
      @tester.convert_participants("#{@user.nickname}").should == [@user.id.to_s]
    end
    
    it "should remove nil entries" do
      @tester.convert_participants("#{@user.nickname};; ;;, ,,dan@Shelby.tv;; ; ,,,").should == [@user.id.to_s, "dan@shelby.tv"]
    end
  end
  
  context "create discussion roll" do
    it "should set metadata on roll correctly" do
      r = @tester.create_discussion_roll_for(@user, @tester.convert_participants("dan@shelby.tv"))
      r.persisted?.should == true
      r = r.reload
      r.creator.should == @user
      r.roll_type.should == Roll::TYPES[:user_discussion_roll]
      r.public.should == false
      r.collaborative.should == true
    end
    
    it "should set participants on roll correctly" do
      r = @tester.create_discussion_roll_for(@user, @tester.convert_participants("dan@shelby.tv"))
      r.persisted?.should == true
      r = r.reload
      r.discussion_roll_participants.should == [@user.id.to_s, "dan@shelby.tv"]
    end
    
    it "should set roll title based on participants" do
      new_user = Factory.create(:user)
      r = @tester.create_discussion_roll_for(@user, @tester.convert_participants("dan@shelby.tv,dan+1@shelby.tv,#{new_user.primary_email}"))
      r.persisted?.should == true
      r = r.reload
      r.title.should == "#{@user.nickname}, dan@shelby.tv, dan+1@shelby.tv, #{new_user.nickname}"
    end
    
    it "should be followed by creator" do
      r = @tester.create_discussion_roll_for(@user, @tester.convert_participants("dan@shelby.tv"))
      r.persisted?.should == true
      r = r.reload
      r.followed_by?(@user).should == true
      @user.reload.following_roll?(r).should == true
    end
    
    it "shold be follwed by other real shelby particpants" do
      new_user = Factory.create(:user)
      r = @tester.create_discussion_roll_for(@user, @tester.convert_participants("dan@shelby.tv,#{new_user.nickname}"))
      r.persisted?.should == true
      r = r.reload
      r.followed_by?(new_user).should == true
      new_user.reload.following_roll?(r).should == true
    end
  end
  
  context "find discussion roll" do
    before(:each) do
      @other_user = Factory.create(:user)
    end
    
    it "should find a roll created by the given user" do
      r = @tester.create_discussion_roll_for(@user, @tester.convert_participants(@other_user.primary_email))
      
      @tester.find_discussion_roll_for(@user, @tester.convert_participants(@other_user.primary_email)).should == r
    end
    
    it "should find a roll when created by a different user" do
      r = @tester.create_discussion_roll_for(@user, @tester.convert_participants(@other_user.primary_email))
      
      @tester.find_discussion_roll_for(@other_user, @tester.convert_participants(@user.primary_email)).should == r
    end
    
    it "should find a roll with all the email participants" do
      em1, em2 = Factory.next(:primary_email), Factory.next(:primary_email)
      r = @tester.create_discussion_roll_for(@user, @tester.convert_participants("#{em1};#{em2}"))
      
      @tester.find_discussion_roll_for(@user, @tester.convert_participants("#{em1};#{em2}")).should == r
    end
    
    it "should find a roll with all the mix of participants (when created by a different user)" do
      em1, em2 = Factory.next(:primary_email), Factory.next(:primary_email)
      r = @tester.create_discussion_roll_for(@user, @tester.convert_participants("#{em1};#{em2},#{@other_user.nickname}"))
      
      @tester.find_discussion_roll_for(@other_user, @tester.convert_participants("#{em1};#{em2},#{@user.nickname}")).should == r
    end
    
    it "should not find a roll of [a, b] when looking for [a, b, c]" do
      em1, em2, em3 = Factory.next(:primary_email), Factory.next(:primary_email), Factory.next(:primary_email)
      r = @tester.create_discussion_roll_for(@user, @tester.convert_participants("#{em1};#{em2}"))
      
      @tester.find_discussion_roll_for(@user, @tester.convert_participants("#{em1};#{em2};#{em3}")).should == nil
    end
    
    
  end
  
end