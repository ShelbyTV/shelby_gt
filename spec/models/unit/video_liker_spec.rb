require 'spec_helper'

# Unit: don't hit DB, check on internals of model
describe VideoLiker do
  before(:each) do
    @user = Factory.create(:user, :avatar_file_name => "somefile.png")
    @vl = Factory.create(:video_liker, :user => @user)
  end

  context "refresh_user_data!" do

    it "refreshes the denormalized user data from the user model" do
      @vl.refresh_user_data!

      expect(@vl.name).to eql @user.name
      expect(@vl.nickname).to eql @user.nickname
      expect(@vl.user_image).to eql @user.user_image
      expect(@vl.user_image_original).to eql @user.user_image_original
      expect(@vl.has_shelby_avatar).to be_true
    end

  end

end
