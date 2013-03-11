require "spec_helper"

describe StatsMailer do
  describe "weekly_curator_stats" do
    before(:all) do
      @user_to = Factory.create(:user, :primary_email => 'user@example.com', :name => "Some One")
      @email = StatsMailer.weekly_curator_stats(@user_to)
    end

    it "renders the headers" do
      @email.subject.should eq("Some One, check out your Shelby stats")
      @email.to.should eq([@user_to.primary_email])
      @email.from.should eq([Settings::Email.notification_sender])
    end

    it "should contain a link to the user's weekly stats page" do
      @email.body.encoded.should have_tag('a', :with => { :href => "#{Settings::Email.web_url_base}/user/#{@user_to.id}/stats" })
    end

  end

end
