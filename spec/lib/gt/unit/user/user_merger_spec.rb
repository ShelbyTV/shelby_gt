require 'spec_helper'
require 'user_merger'

# UNIT test
describe GT::UserMerger do

  before(:each) do
    GT::UserTwitterManager.stub(:follow_all_friends_public_rolls)
    GT::UserFacebookManager.stub(:follow_all_friends_public_rolls)
    GT::PredatorManager.stub(:initialize_video_processing)
    @omniauth = {
      "provider" => "twitter",
      "uid" => "4321",
      "credentials" => {
        "token" => "somelongtoken"
      },
      "info" => {
        "name" => "Foo Bar"
      }
    }
  end

  context "pre-merge" do
    context "handle into_user validity" do
      before(:each) do
        @into_user = Factory.create(:user)
        @other_user = Factory.create(:user)
      end

      it "should raise an ArgumentError if not given two Users" do
        lambda {
          GT::UserMerger.merge_users(nil, @into_user).should == false
        }.should raise_error(ArgumentError)
        lambda {
          GT::UserMerger.merge_users(@other_user, nil).should == false
        }.should raise_error(ArgumentError)
        lambda {
          GT::UserMerger.merge_users(nil, nil).should == false
        }.should raise_error(ArgumentError)
      end

      it "should create special rolls for into_user" do
        GT::UserMerger.stub(:move_authentications).and_return(true)
        GT::UserMerger.stub(:merge_rolls).and_return(true)
        GT::UserMerger.stub(:change_roll_ownership).and_return(true)
        GT::UserMerger.stub(:move_dashboard_entries).and_return(true)
        GT::UserMerger.stub(:follow_all_friends_public_rolls).and_return(true)
        GT::UserMerger.stub(:initialize_video_processing).and_return(true)

        @into_user.public_roll.should == nil
        @into_user.watch_later_roll.should == nil
        @into_user.upvoted_roll.should == nil
        @into_user.viewed_roll.should == nil

        lambda {
          GT::UserMerger.merge_users(@other_user, @into_user)
        }.should change { Roll.count } .by(4)

        @into_user.public_roll.should_not == nil
        @into_user.watch_later_roll.should_not == nil
        @into_user.upvoted_roll.should_not == nil
        @into_user.viewed_roll.should_not == nil
      end

    end
  end

  context "normal merge_users" do
    before(:each) do
      @other_user = Factory.create(:user)
      @into_user = Factory.create(:user)
      # Users are fleshed out appropriately in the contexts that require it
    end

    context "destroy other_user" do
      before(:each) do
        GT::UserMerger.stub(:ensure_valid_user).and_return(true)
        GT::UserMerger.stub(:move_authentications).and_return(true)
        GT::UserMerger.stub(:merge_rolls).and_return(true)
        GT::UserMerger.stub(:change_roll_ownership).and_return(true)
        GT::UserMerger.stub(:move_dashboard_entries).and_return(true)
        GT::UserMerger.stub(:follow_all_friends_public_rolls).and_return(true)
        GT::UserMerger.stub(:initialize_video_processing).and_return(true)
      end

      it "should destroy other_user if everything else succeeds" do
        lambda {
          GT::UserMerger.merge_users(@other_user, @into_user)
        }.should change { User.count } .by(-1)

        User.find_by_id(@other_user.id).should == nil
        User.find_by_id(@into_user.id).should == @into_user
      end
    end

    context "handle Authentications" do
      before(:each) do
        GT::UserMerger.stub(:ensure_valid_user).and_return(true)
        #GT::UserMerger.stub(:move_authentications).and_return(true)
        GT::UserMerger.stub(:merge_rolls).and_return(true)
        GT::UserMerger.stub(:change_roll_ownership).and_return(true)
        GT::UserMerger.stub(:move_dashboard_entries).and_return(true)
        GT::UserMerger.stub(:follow_all_friends_public_rolls).and_return(true)
        GT::UserMerger.stub(:initialize_video_processing).and_return(true)

        # Factory.create(:user) adds 1 auth
        @other_user_orig_auths = Array.new @other_user.authentications
        @into_user_orig_auths = Array.new @into_user.authentications
      end

      it "should handle zero auths on other_user" do
        @other_user.authentications = nil
        @other_user.save

        lambda {
          GT::UserMerger.merge_users(@other_user, @into_user).should == true
        }.should_not change { @into_user.reload.authentications.count }

        @into_user.reload.authentications.should == @into_user_orig_auths
      end

      it "should handle zero auths on into_user" do
        @into_user.authentications = []
        @into_user.save

        lambda {
          GT::UserMerger.merge_users(@other_user, @into_user).should == true
        }.should change { @into_user.reload.authentications.count } .by(@other_user_orig_auths.size)

        @into_user.reload.authentications.should == @other_user_orig_auths
      end

      it "should move other_user auths into into_user" do
        lambda {
          GT::UserMerger.merge_users(@other_user, @into_user).should == true
        }.should change { @into_user.reload.authentications.count } .by(@other_user_orig_auths.size)

        @into_user.reload.authentications.should == @into_user_orig_auths + @other_user_orig_auths
      end

      it "should rebuild/expand other_user's auth if other_user is a faux user and their omniauth info is passed in" do
        @other_user.user_type = User::USER_TYPE[:faux]

        lambda {
          GT::UserMerger.merge_users(@other_user, @into_user, @omniauth).should == true
        }.should change { @into_user.reload.authentications.count } .by(@other_user_orig_auths.size)

        new_auth = @into_user.reload.authentications.last
        new_auth.provider.should == 'twitter'
        new_auth.uid.should == '4321'
        new_auth.name.should == 'Foo Bar'
        new_auth.oauth_token.should == 'somelongtoken'

        @into_user.authentications.should_not == @into_user_orig_auths + @other_user_orig_auths
      end

      it "should not rebuild/expand other_user's auth if other_user is not a faux user" do
        GT::UserMerger.merge_users(@other_user, @into_user, @omniauth)
        @into_user.reload.authentications.should == @into_user_orig_auths + @other_user_orig_auths
      end
    end


    context "handle special Rolls" do
      before(:each) do
        GT::UserMerger.stub(:ensure_valid_user).and_return(true)
        GT::UserMerger.stub(:move_authentications).and_return(true)
        #GT::UserMerger.stub(:merge_rolls).and_return(true)
        GT::UserMerger.stub(:change_roll_ownership).and_return(true)
        GT::UserMerger.stub(:move_dashboard_entries).and_return(true)
        GT::UserMerger.stub(:follow_all_friends_public_rolls).and_return(true)
        GT::UserMerger.stub(:initialize_video_processing).and_return(true)

        # Create special rolls for each user
        @other_user.public_roll = @other_public_roll = Factory.create(:roll, :creator => @other_user)
        @other_user.watch_later_roll = @other_watch_later_roll = Factory.create(:roll, :creator => @other_user)
        @other_user.upvoted_roll = @other_upvoted_roll = Factory.create(:roll, :creator => @other_user)
        @other_user.viewed_roll = @other_viewed_roll = Factory.create(:roll, :creator => @other_user)
        @other_user.save

        @into_user.public_roll = @into_public_roll = Factory.create(:roll, :creator => @into_user)
        @into_user.watch_later_roll = @into_watch_later_roll = Factory.create(:roll, :creator => @into_user)
        @into_user.upvoted_roll = @into_upvoted_roll = Factory.create(:roll, :creator => @into_user)
        @into_user.viewed_roll = @into_viewed_roll = Factory.create(:roll, :creator => @into_user)
        @into_user.save

        #create some frames to work with
        @f1 = Factory.create(:frame, :roll => @other_public_roll, :creator => @other_user)
        @f2 = Factory.create(:frame, :roll => @other_public_roll, :creator => @other_user)
        @f3 = Factory.create(:frame, :roll => @other_public_roll, :creator => @other_user)
        @f4 = Factory.create(:frame, :roll => @other_watch_later_roll, :creator => @other_user)
        @f5 = Factory.create(:frame, :roll => @other_upvoted_roll, :creator => @other_user)
        @f6 = Factory.create(:frame, :roll => @other_viewed_roll, :creator => @other_user)
        @third_party = Factory.create(:user)
        @third_party_frame = Factory.create(:frame, :roll => @other_viewed_roll, :creator => @third_party)
      end

      it "should destroy the special rolls of other_user" do
        lambda {
          GT::UserMerger.merge_users(@other_user, @into_user).should == true
        }.should change { Roll.count } .by(-4)

        Roll.find_by_id(@other_public_roll.id).should == nil
        Roll.find_by_id(@other_watch_later_roll.id).should == nil
        Roll.find_by_id(@other_upvoted_roll.id).should == nil
        Roll.find_by_id(@other_viewed_roll.id).should == nil
      end

      it "should move frames from special rolls of other_user to respective frames of into_user" do
        lambda {
          GT::UserMerger.merge_users(@other_user, @into_user).should == true
        }.should_not change { Frame.count }

        @f1.reload.roll_id.should == @into_public_roll.id
        @f2.reload.roll_id.should == @into_public_roll.id
        @f3.reload.roll_id.should == @into_public_roll.id
        @f4.reload.roll_id.should == @into_watch_later_roll.id
        @f5.reload.roll_id.should == @into_upvoted_roll.id
        @f6.reload.roll_id.should == @into_viewed_roll.id
        @third_party_frame.reload.roll_id.should == @into_viewed_roll.id
      end

      it "should move the followers of other_user's rolls to into_user's respective rolls" do
        other_follower_1 = Factory.create(:user)
        @other_user.public_roll.add_follower(other_follower_1)
        other_follower_2 = Factory.create(:user)
        @other_user.public_roll.add_follower(other_follower_2)

        lambda {
          GT::UserMerger.merge_users(@other_user, @into_user).should == true
        }.should change { @into_user.public_roll.reload.following_users.count } .by(2)

        other_follower_1.reload.roll_followings.reload.size.should == 1
        @into_user.public_roll.followed_by?(other_follower_1).should == true
        other_follower_2.reload.roll_followings.size.should == 1
        @into_user.public_roll.followed_by?(other_follower_2).should == true
      end

      it "should change the creator of moved frames (when they're created by other_user)" do
        lambda {
          GT::UserMerger.merge_users(@other_user, @into_user).should == true
        }.should_not change { Frame.count }

        @f1.reload.creator_id.should == @into_user.id
        @f2.reload.creator_id.should == @into_user.id
        @f3.reload.creator_id.should == @into_user.id
        @f4.reload.creator_id.should == @into_user.id
        @f5.reload.creator_id.should == @into_user.id
        @f6.reload.creator_id.should == @into_user.id
        @third_party_frame.creator_id.should == @third_party.id
      end

      it "should not choke if some of other_user's special rolls are nil" do
        @other_user.public_roll = nil
        @other_user.watch_later_roll = nil
        @other_user.upvoted_roll = nil
        @other_user.viewed_roll = nil
        @other_user.save

        lambda {
          GT::UserMerger.merge_users(@other_user, @into_user).should == true
        }.should_not change { Frame.count }
      end
    end


    context "handle created Rolls" do
      before(:each) do
        GT::UserMerger.stub(:ensure_valid_user).and_return(true)
        GT::UserMerger.stub(:move_authentications).and_return(true)
        GT::UserMerger.stub(:merge_rolls).and_return(true)
        #GT::UserMerger.stub(:change_roll_ownership).and_return(true)
        GT::UserMerger.stub(:move_dashboard_entries).and_return(true)
      end

      it "should work when other_user has not created any rolls" do
        lambda {
          GT::UserMerger.merge_users(@other_user, @into_user).should == true
        }.should_not change { Roll.where(:creator_id => @into_user.id).count }
      end

      it "should change the owner of all rolls created by other_user" do
        other_r1 = Factory.create(:roll, :creator => @other_user)
        other_r2 = Factory.create(:roll, :creator => @other_user)
        other_r3 = Factory.create(:roll, :creator => @other_user)

        lambda {
          GT::UserMerger.merge_users(@other_user, @into_user).should == true
        }.should change { Roll.where(:creator_id => @into_user.id).count } .by(3)

        other_r1.creator.should == @into_user
        other_r2.creator.should == @into_user
        other_r3.creator.should == @into_user
      end

      it "should not change roll followers" do
        other_r1 = Factory.create(:roll, :creator => @other_user)
        follower_1 = Factory.create(:user)
        other_r1.add_follower(follower_1)
        follower_2 = Factory.create(:user)
        other_r1.add_follower(follower_2)

        lambda {
          GT::UserMerger.merge_users(@other_user, @into_user).should == true
        }.should_not change { other_r1.following_users.count }

        follower_1.reload.following_roll?(other_r1.reload).should == true
        follower_2.reload.following_roll?(other_r1.reload).should == true
      end

      it "should change the creator of frames created by other_user" do
        other_r1 = Factory.create(:roll, :creator => @other_user)
        other_f1 = Factory.create(:frame, :roll => other_r1, :creator => @other_user)
        other_f2 = Factory.create(:frame, :roll => other_r1, :creator => @other_user)

        third_party = Factory.create(:user)
        third_party_f1 = Factory.create(:frame, :roll => other_r1, :creator => third_party)

        lambda {
          GT::UserMerger.merge_users(@other_user, @into_user).should == true
        }.should change { Frame.where(:creator_id => @into_user.id).count } .by(2)

        other_f1.reload.creator.should == @into_user
        other_f2.reload.creator.should == @into_user
        third_party_f1.reload.creator.should == third_party
      end
    end


    context "handle DashboardEntries" do
      before(:each) do
        GT::UserMerger.stub(:ensure_valid_user).and_return(true)
        GT::UserMerger.stub(:move_authentications).and_return(true)
        GT::UserMerger.stub(:merge_rolls).and_return(true)
        GT::UserMerger.stub(:change_roll_ownership).and_return(true)
        #GT::UserMerger.stub(:move_dashboard_entries).and_return(true)
      end

      it "should work when other_user has no DashboardEntries" do
        lambda {
          GT::UserMerger.merge_users(@other_user, @into_user).should == true
        }.should_not change { @into_user.dashboard_entries.count }
      end

      it "should change .user from other_user to into_user" do
        other_dbe_1 = Factory.create(:dashboard_entry, :user => @other_user)
        other_dbe_2 = Factory.create(:dashboard_entry, :user => @other_user)
        other_dbe_3 = Factory.create(:dashboard_entry, :user => @other_user)

        into_dbe_1 = Factory.create(:dashboard_entry, :user => @into_user)

        lambda {
          GT::UserMerger.merge_users(@other_user, @into_user).should == true
        }.should change { @into_user.dashboard_entries.count } .by(3)

        other_dbe_1.reload.user.should == @into_user
        other_dbe_2.reload.user.should == @into_user
        other_dbe_3.reload.user.should == @into_user
      end
    end

    context "follow friends from social networks" do
      before(:each) do
        GT::UserMerger.stub(:ensure_valid_user).and_return(true)
        GT::UserMerger.stub(:move_authentications).and_return(true)
        GT::UserMerger.stub(:merge_rolls).and_return(true)
        GT::UserMerger.stub(:change_roll_ownership).and_return(true)
      end

      it "should follow all of the merged user's friends from social networks that shelby already knows about" do
        GT::UserTwitterManager.should_receive(:follow_all_friends_public_rolls).with(@into_user)
        GT::UserFacebookManager.should_receive(:follow_all_friends_public_rolls).with(@into_user)

        GT::UserMerger.merge_users(@other_user, @into_user)
      end
    end

    context "initialize video processing" do
      before(:each) do
        GT::UserMerger.stub(:ensure_valid_user).and_return(true)
        GT::UserMerger.stub(:move_authentications).and_return(true)
        GT::UserMerger.stub(:merge_rolls).and_return(true)
        GT::UserMerger.stub(:change_roll_ownership).and_return(true)
      end

      it "should initialize video processing for authed service being merged in from a faux user" do
        @other_user.user_type = User::USER_TYPE[:faux]
        GT::PredatorManager.should_receive(:initialize_video_processing).with(@into_user, @into_user.authentications.last)

        GT::UserMerger.merge_users(@other_user, @into_user, @omniauth)
      end

      it "should not initialize video processing if the merged in user is not faux" do
        GT::PredatorManager.should_not_receive(:initialize_video_processing)

        GT::UserMerger.merge_users(@other_user, @into_user, @omniauth)
      end

      it "should not initialize video processing if merged in user is faux but no omniauth was passed in" do
        @other_user.user_type = User::USER_TYPE[:faux]
        GT::PredatorManager.should_not_receive(:initialize_video_processing)

        GT::UserMerger.merge_users(@other_user, @into_user)
      end
    end

  end
end