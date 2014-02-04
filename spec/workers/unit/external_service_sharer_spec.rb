require 'spec_helper'

# UNIT test
describe ExternalServiceSharer do
  before(:each) do
    @user = Factory.create(:user, :authentications => [
      FactoryGirl.create(:authentication, :provider => "twitter"), FactoryGirl.create(:authentication, :provider => "facebook")
    ])
    @roll = Factory.create(:roll, :creator => @user)
    @frame = Factory.create(:frame, :roll => @roll, :conversation => Factory.create(:conversation))

    User.stub(:find).with(@user.id.to_s).and_return(@user)
    Frame.stub(:find).with(@frame.id.to_s).and_return(@frame)

    resp = {"awesm_urls" => [
      {"service"=>"twitter", "parent"=>nil, "original_url"=>"http://henrysztul.info", "redirect_url"=>"http://henrysztul.info?awesm=shl.by_4", "awesm_id"=>"shl.by_4", "awesm_url"=>"http://shl.by/4", "user_id"=>nil, "path"=>"4", "channel"=>"twitter", "domain"=>"shl.by"},
      {"service"=>"facebook", "parent"=>nil, "original_url"=>"http://henrysztul.info", "redirect_url"=>"http://henrysztul.info?awesm=shl.by_fb", "awesm_id"=>"shl.by_fb", "awesm_url"=>"http://shl.by/fb", "user_id"=>nil, "path"=>"fb", "channel"=>"facebook-post", "domain"=>"shl.by"}
    ]}
    Awesm::Url.stub(:batch).and_return([200, resp])
  end

  it "looks up db objects that were stored as id strings by Resque" do
    User.should_receive(:find).with(@user.id.to_s)
    Frame.should_receive(:find).with(@frame.id.to_s)

    ExternalServiceSharer.perform(@frame.id.to_s, [], nil, 'testing', @user.id.to_s)
  end

  context "social" do
    before(:each) do
      GT::SocialPoster.stub(:post_to_twitter)
      GT::SocialPoster.stub(:post_to_facebook)
    end

    it "calls SocialPoster with the proper params for each social service" do
      GT::SocialPoster.should_receive(:post_to_twitter).with(@user, "testing http://shl.by/4")
      GT::SocialPoster.should_receive(:post_to_facebook).with(@user, "testing http://shl.by/fb", @frame)

      ExternalServiceSharer.perform(@frame.id.to_s, ['twitter', 'facebook'], nil, 'testing', @user.id.to_s)
    end

    it "gets shortlinks" do
      GT::LinkShortener.should_receive(:get_or_create_shortlinks).and_call_original

      ExternalServiceSharer.perform(@frame.id.to_s, ['twitter', 'facebook'], nil, 'testing', @user.id.to_s)
    end
  end

  context "email" do
    before(:each) do
      @user.stub(:store_autocomplete_info)
      GT::SocialPoster.stub(:email_frame)
    end

    it "calls SocialPoster with the proper params for email" do
      GT::SocialPoster.should_receive(:email_frame).with(@user, 'spinsoa@aol.com,iceberg@titanic.net', 'testing', @frame)

      ExternalServiceSharer.perform(@frame.id.to_s, ['email'], 'spinsoa@aol.com,iceberg@titanic.net', 'testing', @user.id.to_s)
    end

    it "tries to save email addresses to user's autocomplete" do
      @user.should_receive(:store_autocomplete_info).with(:email, 'spinsoa@aol.com,iceberg@titanic.net')

      ExternalServiceSharer.perform(@frame.id.to_s, ['email'], 'spinsoa@aol.com,iceberg@titanic.net', 'testing', @user.id.to_s)
    end

    it "doesn't get shortlinks" do
      GT::LinkShortener.should_not_receive(:get_or_create_shortlinks)

      ExternalServiceSharer.perform(@frame.id.to_s, ['email'], 'spinsoa@aol.com,iceberg@titanic.net', 'testing', @user.id.to_s)
    end
  end

end