require 'spec_helper'

describe DashboardEntryCreator do
  before(:each) do
    @observer = Factory.create(:user)
    @frame = Factory.create(:frame)
  end

  it "calls the Framer to create a dashboard entry with the proper params" do
    Frame.should_receive(:find).with(@frame.id).and_return(@frame)
    GT::Framer.should_receive(:create_dashboard_entries).with(@frame, DashboardEntry::ENTRY_TYPE[:new_social_frame], [@observer.id], {}, true)

    DashboardEntryCreator.perform(@frame.id, DashboardEntry::ENTRY_TYPE[:new_social_frame], [@observer.id], {}, true)
  end
end