require 'spec_helper'

require 'social_sorter'

# INTEGRATION test (b/c it relies on and implicitly tests UserManager)
describe GT::SocialSorter do
  before(:each) do
    # we sleep when finding a new user, need to stub that
    EventMachine::Synchrony.stub(:sleep)

    @observer = Factory.create(:user)

    @existing_user = Factory.create(:user, :user_type => User::USER_TYPE[:faux])
    @existing_user_nick, @existing_user_provider, @existing_user_uid = "nick1", "ss_1#{rand.to_s}", "uid001#{rand.to_s}"
    auth = Authentication.new
    auth.provider = @existing_user_provider
    auth.uid = @existing_user_uid
    @existing_user.authentications << auth
    @existing_user.save

    @existing_user_public_roll = Factory.create(:roll, :creator => @existing_user, :title => @existing_user.nickname)
    @existing_user.public_roll = @existing_user_public_roll
    @existing_user.save

    @video = Factory.create(:video)
  end

  context "public social postings" do
    before(:each) do
      @existing_user.user_type = User::USER_TYPE[:faux]
      @existing_user.save

      @existing_user_random_msg = Message.new
      @existing_user_random_msg.nickname = @existing_user.nickname
      @existing_user_random_msg.origin_network = @existing_user_provider
      @existing_user_random_msg.origin_user_id = @existing_user_uid
      @existing_user_random_msg.origin_id = rand.to_s
      @existing_user_random_msg.public = true
    end

    it "should add to public Roll of existing faux User" do
      lambda {
        res = GT::SocialSorter.sort(@existing_user_random_msg, {:video => @video, :from_deep => false}, @observer)
        res.should_not == false
        res[:frame].roll.should == @existing_user.public_roll
        res[:frame].persisted?.should == true
        res[:frame].conversation.persisted?.should == true
        res[:frame].conversation.messages[0].persisted?.should == true
      }.should change { @existing_user.public_roll.reload.frames.count }.by(1)
    end

    it "should add to public Roll of real User" do
      @existing_user.user_type = User::USER_TYPE[:real]
      @existing_user.save

      lambda {
        res = GT::SocialSorter.sort(@existing_user_random_msg, {:video => @video, :from_deep => false}, @observer)
        res.should_not == false
        res[:frame].roll.should ==  @existing_user.public_roll
        res[:dashboard_entries].count.should == 2
        res[:dashboard_entries][1].user.should == @observer
        res[:dashboard_entries][1].roll.should ==  @existing_user.public_roll
        res[:dashboard_entries][1].action.should == DashboardEntry::ENTRY_TYPE[:new_social_frame]
        res[:dashboard_entries][1].frame.should == res[:frame]
      }.should change { @existing_user.public_roll.reload.frames.count }.by(1)
    end

    it "should set existing User on the Message" do
      res = GT::SocialSorter.sort(@existing_user_random_msg, {:video => @video, :from_deep => false}, @observer)
      res[:frame].conversation.messages[0].user.should == @existing_user
      res[:frame].conversation.messages[0].user.should == res[:frame].creator
    end

    it "should add to public Roll of new faux User"  do
      m = Message.new
      m.nickname = "FakeNick001"
      m.origin_network = "FakeNet"
      m.origin_user_id = "RandomId001"
      m.origin_id = "RandomId998"
      m.user_image_url = "img"
      m.public = true

      lambda {
        res = GT::SocialSorter.sort(m, {:video => @video, :from_deep => false}, @observer)
        res[:frame].creator.nickname.should == "FakeNick001"
        res[:frame].creator.user_image.should == "img"
      }.should change { User.count }.by(1)
    end

    it "should set faux User on the Message" do
      m = Message.new
      m.nickname = "FakeNick001"
      m.origin_network = "FakeNet"
      m.origin_user_id = "RandomId001--b"
      m.origin_id = "RandomId998--b"
      m.public = true

      res = GT::SocialSorter.sort(m, {:video => @video, :from_deep => false}, @observer)
      res[:frame].conversation.messages[0].user.should == res[:frame].creator
    end

    it "should do nothing if this social posting has already been posted to User's public Roll" do
      lambda {
        GT::SocialSorter.sort(@existing_user_random_msg, {:video => @video, :from_deep => false}, @observer).should_not == false
        GT::SocialSorter.sort(@existing_user_random_msg, {:video => @video, :from_deep => false}, @observer).should == false
        GT::SocialSorter.sort(@existing_user_random_msg, {:video => @video, :from_deep => false}, @observer).should == false
        GT::SocialSorter.sort(@existing_user_random_msg, {:video => @video, :from_deep => false}, @observer).should == false
      }.should change { @existing_user.public_roll.reload.frames.count }.by(1)
    end

    it "should add this post as a message to previously posted Frame if Video was posted < 24 hours ago" do
      # Often times a user/brand will post the same video multiple times to get more audience, or to fix their original tweet
      # we don't want to have duplicate Frames, we just want to update the original frame with the addition of this message
      # But we only look back ~24 hours to keep things reasonable

      # original post
      msg = Factory.build(:message, :text => (txt = "t1"), :origin_id => rand.to_s)
      convo = Factory.build(:conversation)
      convo.messages << msg
      orig_post = Factory.create(:frame, :roll => @existing_user.public_roll, :video => @video, :conversation => convo)
      orig_post.reload.conversation.messages.size.should == 1

      # post same video again
      msg2 = @existing_user_random_msg.clone
      msg2.text = (txt2 = "something else")
      msg2.origin_id = rand.to_s
      res2 = nil
      lambda {
        res2 = GT::SocialSorter.sort(msg2, {:video => @video, :from_deep => false}, @observer)
      }.should_not change { Frame.count }
      res2.should == false

      MongoMapper::Plugins::IdentityMap.clear #Need to load this up fresh
      orig_post.conversation.reload.messages.count.should == 2
      orig_post.conversation.messages[0].text.should == txt
      orig_post.conversation.messages[1].text.should == txt2
    end

    it "should not add this post as a message to previous posted Frame if Video was posted > 24 hours ago" do
      #see discussion above

      # original post (26 hours ago)
      orig_post = Factory.create(:frame, :_id => BSON::ObjectId.from_time(28.hours.ago, :unique => true), :roll => @existing_user.public_roll, :video => @video)

      # post same video again
      msg2 = @existing_user_random_msg
      msg2.text = (txt2 = "something else")
      msg2.origin_id = rand.to_s
      res2 = nil
      lambda {
        res2 = GT::SocialSorter.sort(msg2, {:video => @video, :from_deep => false}, @observer)
      }.should change { Frame.count } .by(1)
      res2[:frame].should_not == orig_post
      res2[:frame].conversation.messages.count.should == 1
      res2[:frame].conversation.messages[0].text.should == txt2
    end

    it "should make observing User auto-follow Roll" do
      m = Message.new
      m.nickname = "FakeNick002"
      m.origin_network = "FakeNet"
      m.origin_user_id = "RandomId002"
      m.origin_id = "RandomId997"
      m.public = true

      lambda {
        res = GT::SocialSorter.sort(m, {:video => @video, :from_deep => false}, @observer)
        @observer.reload.following_roll?(res[:frame].roll).should == true
        res[:frame].roll.reload.followed_by?(@observer).should == true
      }.should change { @observer.roll_followings.count }.by(1)
    end

    it "should backfill the observing User's stream when they auto-follow Roll" do
      m = @existing_user_random_msg

      lambda {
        GT::Framer.should_receive(:backfill_dashboard_entries).with(@observer.reload, @existing_user.public_roll.reload, 20)

        res = GT::SocialSorter.sort(m, {:video => @video, :from_deep => false}, @observer)
        @observer.reload.following_roll?(res[:frame].roll).should == true
        res[:frame].roll.reload.followed_by?(@observer).should == true
      }.should change { @observer.roll_followings.count }.by(1)
    end

    it "should make observing User auto-follow Roll even if this Message has already been posted to a Roll" do
      lambda {
        GT::SocialSorter.sort(@existing_user_random_msg, {:video => @video, :from_deep => false}, User.create( :nickname => "#{rand.to_s}-#{Time.now.to_f}"))
      }.should change { Frame.count }.by(1)

      new_observer = Factory.create(:user)

      new_observer.following_roll?(@existing_user.public_roll).should == false
      lambda {
        GT::SocialSorter.sort(@existing_user_random_msg, {:video => @video, :from_deep => false}, new_observer)
        new_observer.following_roll?(@existing_user.public_roll).should == true
        new_observer.reload.following_roll?(@existing_user.public_roll).should == true
        @existing_user.public_roll.reload.followed_by?(new_observer).should == true
      }.should_not change { Frame.count }
    end

    it "should not make observing User auto-follow public Roll if they've unfollowed it" do
      #need to follow first
      @existing_user.public_roll.add_follower(@observer)
      #can now un-follow
      @existing_user.public_roll.remove_follower(@observer)
      @existing_user.public_roll.save
      @observer.save

      @observer.following_roll?(@existing_user.public_roll).should == false
      res = GT::SocialSorter.sort(@existing_user_random_msg, {:video => @video, :from_deep => false}, @observer)
      @observer.following_roll?(@existing_user.public_roll).should == false
      @existing_user.public_roll.followed_by?(@observer).should == false
      @observer.following_roll?(res[:frame].roll).should == false
    end

    it "should not create DashboardEntry for observing user if they unfollowed the poster's roll" do
      #need to follow first
      @existing_user.public_roll.add_follower(@observer)
      #can now un-follow
      @existing_user.public_roll.remove_follower(@observer)
      @existing_user.public_roll.save
      @observer.save

      lambda {
        res = GT::SocialSorter.sort(@existing_user_random_msg, {:video => @video, :from_deep => false}, @observer)
      }.should_not change { @observer.dashboard_entries.count }
    end

    it "should add DashboardEntry for observing User" do
      # b/c we unfollowed earlier...
      @existing_user.public_roll.add_follower(@observer)
      @existing_user.public_roll.save
      @observer.save

      lambda {
        res = GT::SocialSorter.sort(@existing_user_random_msg, {:video => @video, :from_deep => false}, @observer)
        @observer.following_roll?(@existing_user.public_roll).should == true
      }.should change { @observer.dashboard_entries.count }.by(1)
    end


    it "should add DashboardEntry for multiple Users following Roll who are not the observing User" do
      @existing_user.public_roll.add_follower(Factory.create(:user))
      @existing_user.public_roll.add_follower(Factory.create(:user))
      @existing_user.public_roll.add_follower(Factory.create(:user))
      @existing_user.public_roll.save

      lambda {
        res = GT::SocialSorter.sort(@existing_user_random_msg, {:video => @video, :from_deep => false}, @observer)
        res[:dashboard_entries].size.should satisfy { |n| n >= 4 }
      }.should change { DashboardEntry.count }.by_at_least(4)
    end

    it "should create appropriate Frame" do
      lambda {
        res = GT::SocialSorter.sort(@existing_user_random_msg, {:video => @video, :from_deep => false}, @observer)
        f = res[:frame]
        f.is_a?(Frame).should == true
        f.persisted?.should == true
        f.video.should == @video
        f.roll.should == @existing_user.public_roll
        f.roll.creator.should == @existing_user
        f.conversation.persisted?.should == true
        f.creator.should == @existing_user
        f.frame_ancestors.size.should == 0
        f.frame_children.size.should == 0
      }.should change { Frame.count }.by(1)
    end

    it "should create public Message in the Frame's public Conversation" do
      lambda {
        res = GT::SocialSorter.sort(@existing_user_random_msg, {:video => @video, :from_deep => false}, @observer)
        res[:frame].conversation.public?.should == true
        res[:frame].conversation.messages[0].public?.should == true
      }.should change { Conversation.count }.by(1)
    end

    it "should make observing User auto-follow Roll even if this Message has already been posted to a Roll, and observering User should get a DashboardEntry" do
      lambda {
        GT::SocialSorter.sort(@existing_user_random_msg, {:video => @video, :from_deep => false}, Factory.create(:user))
      }.should change { Frame.count }.by(1)

      new_observer = Factory.create(:user)

      new_observer.following_roll?(@existing_user.public_roll).should == false
      lambda {
        lambda {
          GT::Framer.should_receive(:backfill_dashboard_entries)
          GT::SocialSorter.sort(@existing_user_random_msg, {:video => @video, :from_deep => false}, new_observer)
        }.should_not change { Frame.count }
      # we intercept backfill above, but still expecting 1 new dashbaord entry
      }.should change { new_observer.dashboard_entries.count } .by 1
    end

    it "should make observing User auto-follow Roll even if this Message has already been posted to a Roll, and observering User should NOT get a second DashboardEntry if backfill created it" do
      lambda {
        GT::SocialSorter.sort(@existing_user_random_msg, {:video => @video, :from_deep => false}, Factory.create(:user))
      }.should change { Frame.count }.by(1)

      new_observer = Factory.create(:user)

      new_observer.following_roll?(@existing_user.public_roll).should == false
      lambda {
        lambda {
          #GT::Framer.should_receive(:backfill_dashboard_entries)
          GT::SocialSorter.sort(@existing_user_random_msg, {:video => @video, :from_deep => false}, new_observer)
          GT::Framer.should_not_receive(:create_dashboard_entry)
        }.should_not change { Frame.count }
      # didn't intercept backfill above, make sure we don't get 2 dashboard entries
      }.should change { new_observer.dashboard_entries.count } .by 1
    end

  end

  context "private social postings" do
    before(:each) do
      @existing_user_random_msg = Message.new
      @existing_user_random_msg.nickname = @existing_user.nickname
      @existing_user_random_msg.origin_network = @existing_user_provider
      @existing_user_random_msg.origin_user_id = @existing_user_uid
      @existing_user_random_msg.origin_id = rand.to_s
      @existing_user_random_msg.public = false
    end

    it "should not add to public Roll of existing User" do
      lambda {
        lambda {
          res = GT::SocialSorter.sort(@existing_user_random_msg, {:video => @video, :from_deep => false}, @observer)
          res.should_not == false
        }.should change { Frame.count }.by(1)
      }.should_not change { @existing_user.public_roll.reload.frames.count }
    end

    it "should still create faux User" do
      m = Message.new
      m.nickname = "PrivateFakeNick001"
      m.origin_network = "PrivateFakeNet"
      m.origin_user_id = "PrivateRandomId001"
      m.origin_id = "PrivateRandomId998"
      m.public = false

      lambda {
        res = GT::SocialSorter.sort(m, {:video => @video, :from_deep => false}, @observer)
        res[:frame].creator.nickname.should == "PrivateFakeNick001"
      }.should change { User.count }.by(1)
    end

    it "should not add to the public Roll of that faux User" do
      m = Message.new
      m.nickname = "PrivateFakeNick002"
      m.origin_network = "PrivateFakeNet"
      m.origin_user_id = "PrivateRandomId002"
      m.origin_id = "PrivateRandomId997"
      m.public = false

      lambda {
        res = GT::SocialSorter.sort(m, {:video => @video, :from_deep => false}, @observer)
        res[:frame].roll.should == nil
      }.should change { User.count }.by(1)
    end

    it "should only create one DashboardEntry" do
      lambda {
        res = GT::SocialSorter.sort(@existing_user_random_msg, {:video => @video, :from_deep => false}, @observer)
        res.should_not == false
      }.should change { DashboardEntry.count }.by(1)
    end

    it "should add DashboardEntry for observing User (with no Roll)" do
      lambda {
        res = GT::SocialSorter.sort(@existing_user_random_msg, {:video => @video, :from_deep => false}, @observer)
        res.should_not == false
        res[:dashboard_entries].size.should == 1
        res[:dashboard_entries][0].user.should == @observer
      }.should change { DashboardEntry.count }.by(1)
    end

    it "should *not* add DashboardEntrys for multiple Users following Roll who are not the observing User" do
      @existing_user.public_roll.add_follower(Factory.create(:user))
      @existing_user.public_roll.add_follower(Factory.create(:user))
      @existing_user.public_roll.add_follower(Factory.create(:user))
      @existing_user.public_roll.save

      lambda {
        res = GT::SocialSorter.sort(@existing_user_random_msg, {:video => @video, :from_deep => false}, @observer)
        res.should_not == false
        res[:dashboard_entries].size.should == 1
        res[:dashboard_entries][0].user.should == @observer
      }.should change { DashboardEntry.count }.by(1)
    end

    it "should create appropriate Frame (owned by existing User, no Roll)" do
      lambda {
        res = GT::SocialSorter.sort(@existing_user_random_msg, {:video => @video, :from_deep => false}, @observer)
        res.should_not == false
        f = res[:frame]
        f.is_a?(Frame).should == true
        f.persisted?.should == true
        f.video.should == @video
        f.roll.should == nil
        f.conversation.persisted?.should == true
        f.creator.should == @existing_user
        f.frame_ancestors.size.should == 0
        f.frame_children.size.should == 0
      }.should change { Frame.count }.by(1)
    end

    it "should create *private* Message in the Frame's Conversation" do
      lambda {
        res = GT::SocialSorter.sort(@existing_user_random_msg, {:video => @video, :from_deep => false}, @observer)
        res[:frame].conversation.public?.should == false
        res[:frame].conversation.messages[0].public?.should == false
      }.should change { Conversation.count }.by(1)
    end
  end

end
