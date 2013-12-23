require 'spec_helper'
require 'mail_helper'

describe "mail_view/like_notification" do
  it "infers the controller path" do
    controller.request.path_parameters[:controller].should eq("mail_view")
  end

  it "infers the action path" do
    controller.request.path_parameters[:action].should eq("like_notification")
  end

  context "Like by an anonymous User" do
    before(:each) do
      assign(:user_from,{})
      assign(:user_from_name,'Joe Smith')
      assign(:user_from_first_name,'Joe')
      assign(:user_permalink,'jsmith.shelby.tv')
      assign(:frame_permalink,'http://shl.by/xxx')
      assign(:frame_title,'Michael Jackson is cool')
    end

    it "renders the email without suggested users" do
      rendered.should have_content(Settings::Email.like_notification.header)
    end

  end

  context "Like by real User" do
    before(:each) do
    end

    it "renders the email without information about a user" do
      rendered.should have_content(Settings::Email.like_notification.find_more_video)
    end

  end

end
