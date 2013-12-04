require 'spec_helper'
require 'video_liker_manager'

# INTEGRATION test
describe GT::VideoLikerManager do

  before(:each) do
    @v = Factory.create(:video)
  end

  it "returns an empty array when there are no buckets" do
    GT::VideoLikerManager.get_likers_for_video(@v).should be_empty
  end

  it "returns an empty array when there are no likers" do
    VideoLikerBucket.new({:provider_name => @v.provider_name, :provider_id => @v.provider_id, :sequence => 0}).save
    MongoMapper::Plugins::IdentityMap.clear

    GT::VideoLikerManager.get_likers_for_video(@v).should be_empty
  end

  it "returns likers when there are some" do
    liker = Factory.create(:user)
    video_liker = Factory.create(:video_liker, :nickname => liker.nickname, :has_shelby_avatar => false)
    video_liker_bucket = VideoLikerBucket.new({:provider_name => @v.provider_name, :provider_id => @v.provider_id, :sequence => 0})
    video_liker_bucket.likers << video_liker
    video_liker_bucket.save
    MongoMapper::Plugins::IdentityMap.clear

    GT::VideoLikerManager.get_likers_for_video(@v).length.should == 1
  end

  context "multiple buckets" do
    before(:each) do
      Settings::VideoLiker["bucket_size"] = 3

      @video_likers = []
      @buckets = []
      2.times do |i|
        @buckets << Factory.create(:video_liker_bucket, :provider_name => @v.provider_name, :provider_id => @v.provider_id, :sequence => i)
        Settings::VideoLiker.bucket_size.times do
          public_roll = Factory.create(:roll)
          liker = Factory.create(:user, :public_roll => public_roll)
          video_liker = Factory.create(:video_liker, {
            :user_id => liker.id,
            :nickname => liker.nickname,
            :name => liker.name,
            :public_roll => liker.public_roll,
            :user_image => liker.user_image,
            :user_image_original => liker.user_image_original,
            :has_shelby_avatar => liker.has_shelby_avatar
          })
          @video_likers << video_liker
          @buckets[i].likers << video_liker
        end
        @buckets[i].save
      end
      MongoMapper::Plugins::IdentityMap.clear
    end

    it "returns the likers in order of recency for a limit less than the bucket size" do
      expect(GT::VideoLikerManager.get_likers_for_video(@v, {:limit => 2})).to eql [@video_likers[-1], @video_likers[-2]]
    end

    it "returns the likers in order of recency for a limit exactly equal to the bucket size" do
      expect(GT::VideoLikerManager.get_likers_for_video(@v, {:limit => 3})).to eql [@video_likers[-1], @video_likers[-2], @video_likers[-3]]
    end

    it "returns the likers in order of recency for a limit midway through the second bucket" do
      expect(GT::VideoLikerManager.get_likers_for_video(@v, {:limit => 5})).to eql [@video_likers[-1], @video_likers[-2], @video_likers[-3], @video_likers[-4], @video_likers[-5]]
    end

    it "returns the likers in order of recency for a limit that exceeds the current number of likers" do
      expect(GT::VideoLikerManager.get_likers_for_video(@v, {:limit => Settings::VideoLiker.bucket_size * 3})).to eql @video_likers.reverse
    end

    it "returns the right results when the most recent bucket is not full" do
      @buckets.last.likers.slice!(-1)
      @buckets.last.save
      MongoMapper::Plugins::IdentityMap.clear
      expect(GT::VideoLikerManager.get_likers_for_video(@v, {:limit => 3})).to eql [@video_likers[-2], @video_likers[-3], @video_likers[-4]]
    end

    it "returns the right results when there is only one bucket" do
      @buckets.last.destroy
      MongoMapper::Plugins::IdentityMap.clear
      expect(GT::VideoLikerManager.get_likers_for_video(@v, {:limit => 3})).to eql [@video_likers[-4], @video_likers[-5], @video_likers[-6]]
    end
  end

end