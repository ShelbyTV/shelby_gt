# encoding: UTF-8

require 'spec_helper'

#Functional: hit the database, treat model as black box
describe Roll do
  context "not testing subdomain" do
    before(:each) do
      @roll = Factory.create(:roll, :creator => (@creator = Factory.create(:user)), :creator_thumbnail_url => "u://rl")
      @roll_title = @roll.title
      @user = Factory.create(:user)
      @stranger = Factory.create(:user)
    end

    context "database" do
      it "should have an index on [creator_id]" do
        indexes = Roll.collection.index_information.values.map { |v| v["key"] }
        indexes.should include({"a"=>1})
      end

      it "should have an index on [subdomain]" do
        indexes = Roll.collection.index_information.values.map { |v| v["key"] }
        indexes.should include({"k"=>1})
      end

      it "should abbreviate creator_id as :a" do
        Roll.keys["creator_id"].abbr.should == :a
      end

      it "should abbreviate subdomain as :k" do
        Roll.keys["subdomain"].abbr.should == :k
      end

    end

    context "followers" do

      it "should know if a user is following" do
        @roll.followed_by?(@user).should == false

        @roll.add_follower(@user)
        @roll.reload.followed_by?(@user).should == true
      end

      it "should be able to add a follower, who should then know they're following this role" do
        @roll.add_follower(@user)

        @roll.reload.followed_by?(@user).should == true
        @user.reload.following_roll?(@roll).should == true
      end

      it "should NOT be considered 'followed_by' when followings are asymetic (ie. roll has following_user but user doesn't have roll_rollowing)" do
        @roll.add_follower(@user)

        #this is normal
        @roll.reload.followed_by?(@user).should == true

        #make it asymetric
        @user.update_attribute(:roll_followings, [])

        #should no longer be considered followed_by
        @roll.reload.followed_by?(@user).should == false
        #should be considered followed_by in the asymetric sense
        @roll.reload.followed_by?(@user, false).should == true
      end

      it "should add follower when followings are asymetric (ie. roll has following_user but user doesn't have roll_rollowing)" do
        @roll.add_follower(@user)

        #make it asymetric (on user side)
        @user.update_attribute(:roll_followings, [])

        #should no longer be considered followed_by
        @roll.reload.followed_by?(@user).should == false

        #should add follower correctly
        @roll.add_follower(@user)
        @roll.reload.followed_by?(@user).should == true
      end

      it "should add follower when followings are asymetric (ie. user has roll_rollowing but roll doesn't have following_user)" do
        @roll.add_follower(@user)

        #make it asymetric (on roll side)
        @roll.update_attribute(:following_users, [])

        #should no longer be considered followed_by
        @roll.reload.followed_by?(@user).should == false

        #should add follower correctly
        @roll.add_follower(@user)
        @roll.reload.followed_by?(@user).should == true
      end

      it "should email on add follower" do
        lambda {
          @roll.add_follower(@user)
        }.should change(ActionMailer::Base.deliveries,:size).by(1)
      end

      it "should not email on add follower if send_notification=false" do
        lambda {
          @roll.add_follower(@user, false)
        }.should change(ActionMailer::Base.deliveries,:size).by(0)
      end

      it "creates a follow_notification dbe for the followee" do
        Settings::PushNotifications.notification_users_whitelist << @creator.nickname
        ResqueSpec.reset!

        @roll.add_follower(@user)

        DashboardEntryCreator.should have_queue_size_of(1)
        DashboardEntryCreator.should have_queued(
          [nil],
          DashboardEntry::ENTRY_TYPE[:follow_notification],
          [@creator.id],
          {:persist => true, :actor_id => @user.id}
        )
        expect {
          ResqueSpec.perform_next(:dashboard_entries_queue)
        }.to change { DashboardEntry.count }.by(1)

        dbe = DashboardEntry.last
        expect(dbe.user).to eql @creator
        expect(dbe.actor).to eql @user
        expect(dbe.action).to eql DashboardEntry::ENTRY_TYPE[:follow_notification]
        expect(dbe.frame).to be_nil

        Settings::PushNotifications.notification_users_whitelist.clear
      end

      it "does not create a follow_notification dbe if send_notification=false" do
        ResqueSpec.reset!

        @roll.add_follower(@user, false)

        DashboardEntryCreator.should have_queue_size_of(0)
      end

      it "should not add follower if they're already following" do
        lambda {
          @roll.add_follower(@user)
        }.should change { @roll.reload.following_users.count } .by(1)

        lambda {
          @roll.add_follower(@user).should == false
        }.should_not change { @roll.reload.following_users.count }
      end

      it "should be able to remove a follower, who then knows they've unfollowed this role" do
        @roll.add_follower(@user)
        @roll.remove_follower(@user)

        @roll.followed_by?(@user).should == false
        @user.following_roll?(@roll).should == false
        @user.unfollowed_roll?(@roll).should == true
      end

      it "should not remove follower unless they're following" do
        lambda {
          @roll.remove_follower(@user).should == false
        }.should_not change { @roll.following_users.count }
      end

      it "should only remove the follower requested" do
        @roll.add_follower(@user)
        @roll.add_follower(@stranger)
        @roll.remove_follower(@stranger)

        @roll.followed_by?(@stranger).should == false
        @stranger.following_roll?(@roll).should == false
        @stranger.unfollowed_roll?(@roll).should == true

        @roll.followed_by?(@user).should == true
        @user.following_roll?(@roll).should == true
        @user.unfollowed_roll?(@roll).should == false
      end

      it "should be able to remove all followers" do
        @roll.add_follower(@user)
        @roll.add_follower(@stranger)
        @roll.reload.following_users.count.should == 2
        @user.reload.roll_followings.count.should == 1
        @stranger.reload.roll_followings.count.should == 1

        @roll.remove_all_followers!

        @roll.reload.following_users.count.should == 0
        @user.reload.roll_followings.count.should == 0
        @stranger.reload.roll_followings.count.should == 0
      end

      it "should be able to remove all followers even if some are nil" do
        @roll.add_follower(@user)
        @roll.add_follower(@stranger)
        @stranger.destroy
        @roll.reload.following_users.count.should == 2

        @roll.remove_all_followers!

        @roll.reload.following_users.count.should == 0
      end

      it "should be able to hold 1000 following users" do
        u = Factory.create(:user)

        1000.times do
          @roll.following_users << FollowingUser.new(:user => u)
        end
        @roll.save #should not raise an error
      end

      it "should return array of all followers' ids" do
        u1 = Factory.create(:user)
        @roll.add_follower(u1)
        u2 = Factory.create(:user)
        @roll.add_follower(u2)
        u3 = Factory.create(:user)
        @roll.add_follower(u3)

        user_ids = @roll.following_users_ids

        user_ids[0].should be_a(BSON::ObjectId)
        user_ids.include?(u1.id).should == true
        user_ids.include?(u2.id).should == true
        user_ids.include?(u3.id).should == true
      end

      it "should return array of all follower' models" do
        u1 = Factory.create(:user)
        @roll.add_follower(u1)
        u2 = Factory.create(:user)
        @roll.add_follower(u2)
        u3 = Factory.create(:user)
        @roll.add_follower(u3)

        user_models = @roll.following_users_models

        user_models[0].should be_a(User)
        user_models.include?(u1).should == true
        user_models.include?(u2).should == true
        user_models.include?(u3).should == true
      end

    end

    context "permissions" do

      it "should be viewable & invitable to by anybody (even non-logged in) if +public" do
        @roll.creator = @user
        @roll.public = true

        @roll.viewable_by?(nil).should == true

        @roll.viewable_by?(@user).should == true
        @roll.invitable_to_by?(@user).should == true
        @roll.viewable_by?(@stranger).should == true
        @roll.invitable_to_by?(@stranger).should == true
      end

      it "should be postable by anybody if +public and +collaborative" do
        @roll.public = true
        @roll.collaborative = true

        @roll.postable_by?(nil).should == true
        @roll.postable_by?(@stranger).should == true
      end

      it "should be postable only by the owner if +public and -collaborative" do
        @roll.creator = @user
        @roll.public = true
        @roll.collaborative = false

        @roll.postable_by?(@user).should == true
        @roll.postable_by?(@stranger).should == false
        @roll.postable_by?(nil).should == false
      end

      it "should be viewable, postable and invitable-to by followers if it's -public and +collaborative" do
        @roll.creator = @user
        @roll.public = false
        @roll.collaborative = true

        @roll.viewable_by?(@stranger).should == false
        @roll.invitable_to_by?(@stranger).should == false
        @roll.postable_by?(@stranger).should == false
        @roll.postable_by?(nil).should == false

        #get to know that stranger...
        # ie add them as a follower to a private collaborative roll
        @roll.add_follower(@stranger)
        @roll.viewable_by?(@stranger).should == true
        @roll.invitable_to_by?(@stranger).should == true
        @roll.postable_by?(@stranger).should == true
      end

      it "should be leavable iff user is not the creator" do
        @roll.leavable_by?(@stranger).should == true
      end

      it "should not be leavable if the user is the creator" do
        @roll.creator = @user
        @roll.leavable_by?(@user).should == false
      end

    end

    context "upvoted_roll display_thumbnail_url" do
      it "should return regular thumbnail_url when not an upvoted roll" do
        @roll.display_thumbnail_url.should == "u://rl"
      end

      it "should return heart thumbnail_url when an upvoted roll" do
        @roll.upvoted_roll = true
        @roll.display_thumbnail_url.should == "#{Settings::ShelbyAPI.web_root}/images/assets/favorite_roll_avatar.png"
      end
    end

    context "destroy" do
      it "should be destroyable by creator" do
        @roll.destroyable_by?(@creator).should == true
        @roll.destroyable_by?(@stranger).should == false
      end

      it "should be destoyable by anyone if creator is nil" do
        @roll.creator = nil
        @roll.save(:validate => false)
        @roll.destroyable_by?(@creator).should == true
        @roll.destroyable_by?(@stranger).should == true
      end

      it "should NOT be destroyable if it's creators public_roll" do
        @roll.destroyable_by?(@creator).should == true
        @creator.public_roll = @roll
        @creator.save
        @roll.destroyable_by?(@creator).should == false
      end

      it "should NOT be destroyable if it's creators watch_later_roll" do
        @roll.destroyable_by?(@creator).should == true
        @creator.watch_later_roll = @roll
        @creator.save
        @roll.destroyable_by?(@creator).should == false
      end

      it "should NOT be destroyable if it's creators upvoted_roll" do
        @roll.destroyable_by?(@creator).should == true
        @creator.upvoted_roll = @roll
        @creator.save
        @roll.destroyable_by?(@creator).should == false
      end

      it "should NOT be destroyable if it's creators viewed_roll" do
        @roll.destroyable_by?(@creator).should == true
        @creator.viewed_roll = @roll
        @creator.save
        @roll.destroyable_by?(@creator).should == false
      end
    end
  end

  context "testing subdomain" do
    before(:each) do
      @roll = Factory.create(:roll, :roll_type => Roll::TYPES[:special_public_real_user])
      @roll_title = @roll.title
    end

    it "should have a subdomain that matches its title if it's the user's personal roll" do
      @roll.collaborative = false
      @roll.save
      @roll.subdomain.should == @roll_title
      @roll.subdomain_active.should == true
    end

    it "should NOT have a subdomain if it's private" do
      @roll.roll_type = Roll::TYPES[:user_private]
      @roll.collaborative = false
      @roll.public = false
      @roll.save
      @roll.subdomain.nil?.should == true
      @roll.subdomain_active.should == false
      @roll.title = "rolltitle1"
      @roll.save
      @roll.subdomain.nil?.should == true
      @roll.subdomain_active.should == false
    end

    it "should NOT have a subdomain if it's a genius roll" do
      @roll.roll_type = Roll::TYPES[:genius]
      @roll.collaborative = false
      @roll.genius = true
      @roll.save
      @roll.subdomain.nil?.should == true
      @roll.subdomain_active.should == false
      @roll.title = "rolltitle2"
      @roll.save
      @roll.subdomain.nil?.should == true
      @roll.subdomain_active.should == false
    end

    it "should NOT have a subdomain if it's collaborative" do
      @roll.roll_type = Roll::TYPES[:user_public]
      @roll.collaborative = true
      @roll.save
      @roll.subdomain.nil?.should == true
      @roll.subdomain_active.should == false
      @roll.title = "rolltitle3"
      @roll.save
      @roll.subdomain.nil?.should == true
      @roll.subdomain_active.should == false
    end

    it "should remove leading and/or trailing '-' or whitespace from the roll title when creating subdomain" do
      @roll.collaborative = false
      @roll.title = " -ti-tle-  "
      @roll.save
      @roll.subdomain.should == "ti-tle"
      @roll.title = " ---ti-tle--  "
      @roll.save
      @roll.subdomain.should == "ti-tle"
    end

    it "should transform sequences of one or more '_' or '-' or spaces to '-' when creating subdomain" do
      @roll.collaborative = false
      @roll.title = " a_-b__c___d e  f _  g   -- h\ti\t\tj  "
      @roll.save
      @roll.subdomain.should == "a-b-c-d-e-f-g-h-i-j"
    end

    it "should remove any invalid characters when creating subdomain" do
      @roll.collaborative = false
      @roll.title = "!josh^%"
      @roll.save
      @roll.subdomain.should == "josh"
    end

    it "should downcase characters in the roll title when creating subdomain" do
      @roll.collaborative = false
      @roll.title = "RoLLTitLE"
      @roll.save
      @roll.subdomain.should == "rolltitle"
    end

    it "should throw error when trying to create a roll with a subdomain on the blacklist" do
      lambda {
        @roll.collaborative = false
        @roll.title = "anal"
        @roll.save!
      }.should raise_error MongoMapper::DocumentNotValid
    end

    context "subdomain on multiple rolls" do
      before(:each) do
        @second_roll = Factory.create(:roll)
      end

      it "should not raise an error when trying to create two rolls with the same subdomain" do
        lambda {
          @roll.collaborative = false
          @roll.title = "sametitle1"
          @roll.save
          @second_roll.collaborative = false
          @second_roll.title = "sametitle1"
          @second_roll.save
        }.should_not raise_error
      end

      it "should only assign the subdomain to the first roll that tries to get that subdomain" do
          @roll.collaborative = false
          @roll.title = "sametitle2"
          @roll.save
          @second_roll.collaborative = false
          @second_roll.title = "sametitle2"
          @second_roll.save
          @roll.subdomain.should == "sametitle2"
          @roll.subdomain_active.should == true
          @second_roll.subdomain.nil?.should == true
          @second_roll.subdomain_active.should == false
      end

      it "should activate the subdomain of a roll that previously violated the uniquness constraint" do
          @roll.collaborative = false
          @roll.title = "sametitle2"
          @roll.save
          @roll.subdomain.nil?.should == true
          @roll.subdomain_active.should == false
          @roll.title = "newuniquetitle"
          @roll.save
          @roll.subdomain.should == "newuniquetitle"
          @roll.subdomain_active.should == true
      end
    end

    context "permalink" do

      it "should generate permalink for a roll that is a user's public roll" do
        user = Factory.create(:user)
        roll = Factory.create(:roll, :roll_type => Roll::TYPES[:special_public_real_user], :creator => user)
        roll.permalink.should == "#{Settings::ShelbyAPI.web_root}/#{user.nickname}/shares"
      end

      it "should generate permalink for a roll that is not a user's public roll" do
        roll = Factory.create(:roll)
        roll.permalink.should == "#{Settings::ShelbyAPI.web_root}/roll/#{roll.id}"
      end

    end
  end
end
