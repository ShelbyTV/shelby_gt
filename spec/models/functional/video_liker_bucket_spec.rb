require 'spec_helper'

#Functional: hit the database, treat model as black box
describe VideoLikerBucket do
  context "database" do
    it "should have an index on [provider_name, provider_id, sequence]" do
      indexes = VideoLikerBucket.collection.index_information.values.map { |v| v["key"] }
      indexes.should include({"a"=>1, "b"=>1, "c"=>-1})
    end
  end

  context "refresh_user_data!" do

    it "refreshes the user data for all VideoLikers in the bucket" do
      @user = Factory.create(:user, :avatar_file_name => "somefile.png")
      @vl = Factory.create(:video_liker, :user => @user)
      video = Factory.create(:video)
      @vlb = Factory.create(:video_liker_bucket, :provider_name => video.provider_id, :provider_id => video.provider_id, :likers => [@vl])

      @vlb.refresh_user_data!
      @vlb.reload

      liker = @vlb.likers.first
      expect(liker.name).to eql @user.name
      expect(liker.nickname).to eql @user.nickname
      expect(liker.user_image).to eql @user.user_image
      expect(liker.user_image_original).to eql @user.user_image_original
      expect(liker.has_shelby_avatar).to be_true
    end

  end
end
