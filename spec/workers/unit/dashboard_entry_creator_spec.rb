require 'spec_helper'

describe DashboardEntryCreator do
  before(:each) do
    @observer = Factory.create(:user)
    @frame1 = Factory.create(:frame)
    @frame2 = Factory.create(:frame)
  end

  it "calls the Framer to create a dashboard entry with the proper params" do
    Frame.should_receive(:find).with([@frame1.id.to_s, @frame2.id.to_s]).and_return([@frame1, @frame2])
    GT::Framer.should_receive(:create_dashboard_entries).with([@frame1, @frame2], DashboardEntry::ENTRY_TYPE[:new_social_frame], [@observer.id], {})
    GT::AppleIOSPushNotifier.should_not_receive(:push_notification_to_devices_async)

    DashboardEntryCreator.perform([@frame1.id.to_s, @frame2.id.to_s], DashboardEntry::ENTRY_TYPE[:new_social_frame], [@observer.id.to_s], {})
  end

  context "when a push notification will be generated" do

    before(:each) do
      GT::AppleIOSPushNotifier.stub(:push_notification_to_devices_async)
      @dbe_id = BSON::ObjectId.new
    end

    it "passes special parameters to retrieve the created dashboard entries ids from the framer" do
      Frame.should_receive(:find).with([@frame1.id.to_s]).and_return([@frame1])
      GT::Framer.should_receive(:create_dashboard_entries).with([@frame1], DashboardEntry::ENTRY_TYPE[:new_social_frame], [@observer.id], {:acknowledge_write => true, :return_dbe_ids => true}).and_return([@dbe_id])

      DashboardEntryCreator.perform([@frame1.id.to_s], DashboardEntry::ENTRY_TYPE[:new_social_frame], [@observer.id.to_s], {"push_notification_options" => {}})
    end

    it "queues a push notification with id of the generated dashboard entry" do
      devices = ['token']
      alert = "Here's your alert"
      Frame.stub(:find).with([@frame1.id.to_s]).and_return([@frame1])
      GT::Framer.stub(:create_dashboard_entries).and_return([@dbe_id])

      GT::AppleIOSPushNotifier.should_receive(:push_notification_to_devices_async).with(devices, alert, {:dashboard_entry_id => @dbe_id})

      DashboardEntryCreator.perform([@frame1.id.to_s], DashboardEntry::ENTRY_TYPE[:new_social_frame], [@observer.id.to_s], {"push_notification_options" => {"devices" => devices, "alert" => alert}})
    end

  end
end