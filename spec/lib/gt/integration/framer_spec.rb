require 'spec_helper'
require 'framer'

# INTEGRATION test
describe GT::Framer do
  before(:each) do
    @video = Factory.create(:video)
    @frame_creator = Factory.create(:user)
    @message = Message.new
    @message.public = true
  
    @roll_creator = User.create( :nickname => "#{rand.to_s}-#{Time.now.to_f}" )
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
    
    it "should comply on dupe_frame" do
      f1 = Factory.create(:frame)
      lambda {
        GT::Framer.dupe_frame!(f1, Factory.create(:user), @roll)
        GT::Framer.dupe_frame!(f1, Factory.create(:user), @roll)
      }.should change { @roll.reload.frame_count } .by(2)
    end
  end
  
end
