require 'spec_helper'

# Unit: don't hit DB, check on internals of model
describe VideoLikerBucket do
  before(:each) do
    @vlb = Factory.create(:video_liker_bucket)
  end

  it "uses the database video-liker" do
    @vlb.database.name.should =~ /.*video-liker/
  end

  it "has the correct keys, abbreviations, and default values" do
    VideoLikerBucket.keys.keys.should include("provider_name")
    VideoLikerBucket.keys["provider_name"].abbr.should == :a

    VideoLikerBucket.keys.keys.should include("provider_id")
    VideoLikerBucket.keys["provider_id"].abbr.should == :b

    VideoLikerBucket.keys.keys.should include("sequence")
    VideoLikerBucket.keys["sequence"].abbr.should == :c
    @vlb.sequence.should == 0
  end

  context "refresh_user_data!" do

    it "refreshes the user data for all VideoLikers in the bucket" do
      @user = Factory.create(:user, :avatar_file_name => "somefile.png")
      @vl = Factory.create(:video_liker, :user => @user)
      @vlb = Factory.create(:video_liker_bucket, :likers => [@vl])

      liker = @vlb.likers.first
      liker.should_receive(:refresh_user_data!).and_call_original
      @vlb.should_receive(:save)

      @vlb.refresh_user_data!

      expect(liker.name).to eql @user.name
      expect(liker.nickname).to eql @user.nickname
      expect(liker.user_image).to eql @user.user_image
      expect(liker.user_image_original).to eql @user.user_image_original
      expect(liker.has_shelby_avatar).to be_true
    end

  end

end
