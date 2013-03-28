require 'spec_helper'

describe EmailWebhookController do

  before(:each) do
    @u = Factory.create(:user)
    User.stub(:find_by_primary_email).and_return(@u)
  end

  describe "POST 'hook'" do
    it "returns http success" do
      post :hook
      response.should be_success
    end

    it "finds the user" do
      User.should_receive(:find_by_primary_email).with(@u.primary_email)

      post :hook, :headers => "From: Some Guy <#{@u.primary_email}>\n"
    end

    it "looks for links" do

      post :hook, :headers => "From: Some Guy <#{@u.primary_email}>\n", :text => "www.youtube.com here's an email http://example.com?name=val"
    end
  end

end