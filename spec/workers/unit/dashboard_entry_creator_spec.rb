require 'spec_helper'

describe DashboardEntryCreator do
  before(:each) do
    @observer = Factory.create(:user)
    @frame1 = Factory.create(:frame)
    @frame2 = Factory.create(:frame)
  end

  it "calls the Framer to create a dashboard entry with the proper params" do
    Frame.should_receive(:find).with([@frame1.id, @frame2.id]).and_return([@frame1, @frame2])
    GT::Framer.should_receive(:create_dashboard_entries).with([@frame1, @frame2], DashboardEntry::ENTRY_TYPE[:new_social_frame], [@observer.id], {})

    DashboardEntryCreator.perform([@frame1.id, @frame2.id], DashboardEntry::ENTRY_TYPE[:new_social_frame], [@observer.id], {})
  end
end