require 'spec_helper'
require 'framer'

# INTEGRATION test
describe GT::Framer do
  before(:each) do
    @video = Factory.create(:video)
    @frame_creator = Factory.create(:user)
    @message = Message.new
    @message.public = true

    @roll_creator = Factory.create(:user)
    @roll = Factory.create(:roll, :creator => @roll_creator)
    @roll.save
  end

  context "updating the frame_count of the owning roll" do
    it "should comply on re-roll" do
      f1 = Factory.create(:frame)
      lambda {
        res = GT::Framer.re_roll(f1, Factory.create(:user), @roll)
        res = GT::Framer.re_roll(f1, Factory.create(:user), @roll)
      }.should change { @roll.reload.frame_count } .by(2)
    end

    it "should comply on create_frame" do
      lambda {
        res = GT::Framer.create_frame(
          :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
          :creator => @frame_creator,
          :video => @video,
          :message => @message,
          :roll => @roll
          )
        }.should change { @roll.reload.frame_count } .by(1)
    end

    it "should not add a frame to the persisted roll when persist option is set to false" do
      lambda {
        res = GT::Framer.create_frame(
          :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
          :creator => @frame_creator,
          :video => @video,
          :message => @message,
          :roll => @roll,
          :persist => false
          )
        }.should_not change { @roll.reload.frame_count }

      dashboard_user = Factory.create(:user)

      lambda {
        res = GT::Framer.create_frame(
          :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
          :creator => @frame_creator,
          :video => @video,
          :message => @message,
          :dashboard_user_id => dashboard_user.id
        )
        }.should_not change { @roll.reload.frame_count }
    end

    it "should comply on dupe_frame" do
      f1 = Factory.create(:frame)
      lambda {
        GT::Framer.dupe_frame!(f1, Factory.create(:user), @roll)
        GT::Framer.dupe_frame!(f1, Factory.create(:user), @roll)
      }.should change { @roll.reload.frame_count } .by(2)
    end
  end

  context "on create_frame when creating a frame on a roll" do

      before(:each) do
        @lambda = lambda {
          res = GT::Framer.create_frame(
            :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
            :creator => @frame_creator,
            :video => @video,
            :message => @message,
            :roll => @roll
            )
        }
      end

    it "should create a frame" do
      @lambda.should change { Frame.count } .by(1)
    end

    it "should create a conversation" do
      @lambda.should change { Conversation.count } .by(1)
    end

    context "when persist option is set to false" do

      before(:each) do
        @lambda = lambda {
          res = GT::Framer.create_frame(
            :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
            :creator => @frame_creator,
            :video => @video,
            :message => @message,
            :roll => @roll,
            :persist => false
            )
        }
      end

      it "should not persist a frame when persist option is set to false" do
        @lambda.should_not change { Frame.count }
      end

      it "should not persist a conversation when persist option is set to false" do
        @lambda.should_not change { Conversation.count }
      end

    end

  end

  context "on create_frame when creating a single dashboard entry" do

    before(:each) do
      @dashboard_user = Factory.create(:user)
      @lambda = lambda {
        res = GT::Framer.create_frame(
          :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
          :creator => @frame_creator,
          :video => @video,
          :message => @message,
          :dashboard_user_id => @dashboard_user.id
        )
      }
    end

    it "should create a frame" do
      @lambda.should change { Frame.count } .by(1)
    end

    it "should create a conversation for the frame" do
      @lambda.should change { Conversation.count } .by(1)
    end

    it "should create a dashboard entry" do
      @lambda.should change { DashboardEntry.count } .by(1)
    end

    context "when persist option is set to false" do

      before(:each) do
        @lambda = lambda {
          res = GT::Framer.create_frame(
            :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
            :creator => @frame_creator,
            :video => @video,
            :message => @message,
            :dashboard_user_id => @dashboard_user.id,
            :persist => false
          )
        }
      end

      it "should not persist a frame" do
        @lambda.should_not change { Frame.count }
      end

      it "should not persist a conversation" do
        @lambda.should_not change { Conversation.count }
      end

      it "should not persist a dashboard entry" do
        @lambda.should_not change { DashboardEntry.count }
      end

    end

  end

end
