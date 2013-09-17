require 'spec_helper'

describe V1::DashboardEntriesController do

  describe "GET find_entries_with_video" do
    before(:each) do
      @user = Factory.create(:user)
      sign_in @user
      v = Video.new
      v.provider_name = "jengjeng"
      v.provider_id = "llama"
      v.save
      f = Frame.new
      f.video = v
      f.save
      dbe = DashboardEntry.new
      dbe.frame = f;
      @user.name = "jengjeng"
      @user.dashboard_entries << dbe
      @user.save

    end

    it "should find video in dashboard" do
      get :find_entries_with_video, {:auth_token => @user.authentication_token, :format => :json, :provider_id => "llama", :provider_name =>"jengjeng"}
      assigns["frames"].length.should == 1
    end

    it "should not fnd video in dashboard" do
      get :find_entries_with_video, {:auth_token => @user.authentication_token, :format => :json, :provider_id => "llamaz", :provider_name =>"jeng"}
      assigns["frames"].length.should == 0
    end
  end

  describe "GET short_link" do
    before(:each) do
      @channel_user = Factory.create(:user)
      @dashboard_entry = Factory.create(:dashboard_entry, :user => @channel_user)
      @dashboard_entry.short_links[:email] = 'http://some.sh/ort/link'
      Settings::Channels.channels[0]['channel_user_id'] = @channel_user.id.to_s

      DashboardEntry.stub(:find).and_return(@dashboard_entry)
      GT::LinkShortener.stub(:get_or_create_shortlinks).and_return(@dashboard_entry.short_links)
    end

    it "should return 200" do
      get :short_link, :id => @dashboard_entry.id.to_s, :format => :json
      assigns(:status).should eq(200)
    end

    it "should assign correct shortlink" do
      get :short_link, :id => @dashboard_entry.id.to_s, :format => :json
      assigns(:short_link).should eq({'email' => 'http://some.sh/ort/link'})
    end

  end

  describe "PUT update" do
    before(:each) do
      @u = Factory.create(:user)
      sign_in @u
      @d = Factory.create(:dashboard_entry)
    end

    it "should return the dashboard entry to @dashboard and return 200" do
      DashboardEntry.stub(:find) { @d }
      @d.should_receive(:update_attributes!).and_return(@d)
      put :update, :id => @d.id, :format => :json
      assigns(:dashboard_entry).should eq(@d)
      assigns(:status).should eq(200)
    end

    it "should return error if could not find dashboard entry" do
      DashboardEntry.stub(:find) { nil }
      put :update, :id => @d.id, :format => :json
      assigns(:status).should eq(404)
      assigns(:message).should eq("could not find dashboard_entry with id #{@d.id}")
    end

    it "should return error if could not update dashboard entry" do
      DashboardEntry.stub(:find) { @d }
      @d.should_receive(:update_attributes!).and_raise(ArgumentError)
      put :update, :id => @d.id, :format => :json
      assigns(:status).should eq(404)
      assigns(:message).should eq("could not update dashboard_entry: ArgumentError")
    end
  end

end
