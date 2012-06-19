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

      it "should have an identity map" do
        r = Roll.new
        r.save
        Roll.identity_map.size.should > 0
      end

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

    context "upvoted_roll display_<title/thumbnail_url>" do
      it "should return regular title when not an upvoted roll" do
        @roll.display_title.should == @roll_title
      end

      it "should return heart title when an upvoted roll" do
        @roll.upvoted_roll = true
        @roll.display_title.should == "#{@roll.creator.nickname} ♥s"
      end

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
      @roll = Factory.create(:roll)
      @roll_title = @roll.title
    end

    it "should have a subdomain that matches its title if it's the user's personal roll" do
      @roll.collaborative = false
      @roll.save
      @roll.subdomain.should == @roll_title
      @roll.subdomain_active.should == true
    end

    it "should NOT have a subdomain if it's private" do
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

    it "should transform sequences of one or more '_' to '-' when creating subdomain" do
      @roll.collaborative = false
      @roll.title = "a_b__c___d"
      @roll.save
      @roll.subdomain.should == "a-b-c-d"
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
  end
end
