require 'spec_helper'
require 'video_liker_manager'

# INTEGRATION test
describe GT::VideoLikerManager do

  before(:each) do
    @v = Factory.create(:video)
    Settings::VideoLiker["bucket_size"] = 2
  end

  describe "add_liker_for_video" do

    before(:each) do
      @liker = Factory.create(:user)
    end

    it "increments the video's number of likers" do
      GT::VideoLikerManager.add_liker_for_video(@v, @liker)

      expect{@v.reload}.to change(@v, :tracked_liker_count).by(1)
    end

    it "only creates a new bucket if there is no room left in the last one" do
      likers = [Factory.create(:user), Factory.create(:user), Factory.create(:user)]
      # have to create a new bucket
      expect{GT::VideoLikerManager.add_liker_for_video(@v, likers[0])}.to change{VideoLikerBucket.count}.by(1)
      # bucket size is 2 so don't need to create a new bucket
      expect{GT::VideoLikerManager.add_liker_for_video(@v, likers[1])}.not_to change{VideoLikerBucket.count}
      # first bucket is full so need to create a new one again
      expect{GT::VideoLikerManager.add_liker_for_video(@v, likers[2])}.to change{VideoLikerBucket.count}.by(1)

      expect(@v.reload.tracked_liker_count).to eq 3
    end

    it "adds VideoLikers one by one to VideoLikerBuckets with correct sequence numbers" do
      likers = [Factory.create(:user), Factory.create(:user), Factory.create(:user)]
      MongoMapper::Plugins::IdentityMap.clear

      GT::VideoLikerManager.add_liker_for_video(@v, likers[0])
      buckets = VideoLikerBucket.where(:provider_name => @v.provider_name, :provider_id => @v.provider_id)
      expect(buckets.count).to eq 1
      bucket = buckets.sort(:sequence.desc).first
      expect(bucket.sequence).to eq 0
      expect(bucket.likers.count).to eq 1

      GT::VideoLikerManager.add_liker_for_video(@v, likers[1])
      bucket.reload
      expect(bucket.likers.count).to eq 2

      #this one should be added to a new bucket
      GT::VideoLikerManager.add_liker_for_video(@v, likers[2])
      buckets = VideoLikerBucket.where(:provider_name => @v.provider_name, :provider_id => @v.provider_id)
      expect(buckets.count).to eq 2
      bucket = buckets.sort(:sequence.desc).first
      expect(bucket.sequence).to eq 1
      expect(bucket.likers.count).to eq 1
    end

    it "creates the VideoLiker records with the correct attribute values" do
      liker_public_roll = Factory.create(:roll)
      liker = Factory.create(:user, :public_roll => liker_public_roll)
      MongoMapper::Plugins::IdentityMap.clear

      GT::VideoLikerManager.add_liker_for_video(@v, liker)

      video_liker = VideoLikerBucket.where(:provider_name => @v.provider_name, :provider_id => @v.provider_id).first.likers.first
      expect(video_liker.user_id).to eq liker.id
      expect(video_liker.name).to eq liker.name
      expect(video_liker.nickname).to eq liker.nickname
      expect(video_liker.user_image).to eq liker.user_image
      expect(video_liker.user_image_original).to eq liker.user_image_original
      expect(video_liker.has_shelby_avatar).to eq liker.has_shelby_avatar
      expect(video_liker.public_roll_id).to eq liker.public_roll_id
    end

    it "will not insert the same liker into the same bucket twice" do
      liker = Factory.create(:user)

      GT::VideoLikerManager.add_liker_for_video(@v, liker)
      GT::VideoLikerManager.add_liker_for_video(@v, liker)

      bucket = VideoLikerBucket.where(:provider_name => @v.provider_name, :provider_id => @v.provider_id).first
      expect(bucket.likers.count).to eq 1
    end

  end

  describe "get_likers_for_video" do

    it "returns an empty array when there are no buckets" do
      GT::VideoLikerManager.get_likers_for_video(@v).should be_empty
    end

    it "returns an empty array when there are no likers" do
      Factory.create(:video_liker_bucket, :provider_name => @v.provider_name, :provider_id => @v.provider_id, :sequence => 0)
      MongoMapper::Plugins::IdentityMap.clear

      GT::VideoLikerManager.get_likers_for_video(@v).should be_empty
    end

    it "returns likers when there are some" do
      liker = Factory.create(:user)
      video_liker = Factory.create(:video_liker, :nickname => liker.nickname, :has_shelby_avatar => false)
      video_liker_bucket = Factory.create(:video_liker_bucket, :provider_name => @v.provider_name, :provider_id => @v.provider_id, :sequence => 0)
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

  describe "refresh_all_user_data" do

    before(:each) do
      MongoMapper::Helper.drop_all_dbs
      MongoMapper::Helper.ensure_all_indexes

      @user = Factory.create(:user, :avatar_file_name => "somefile.png")

      @video_liker_buckets = []
      2.times do
        vl = Factory.create(:video_liker, :user => @user)
        video = Factory.create(:video)
        vlb = Factory.create(:video_liker_bucket, :provider_name => video.provider_name, :provider_id => video.provider_id, :likers => [vl])
        vlb.save
        @video_liker_buckets << vlb
      end

      MongoMapper::Plugins::IdentityMap.clear
    end

    it "refreshes the user data for all likers in all buckets" do
      GT::VideoLikerManager.refresh_all_user_data

      2.times do |i|
        @video_liker_buckets[i].reload
        liker = @video_liker_buckets[i].likers.first
        expect(liker.name).to eql @user.name
        expect(liker.nickname).to eql @user.nickname
        expect(liker.user_image).to eql @user.user_image
        expect(liker.user_image_original).to eql @user.user_image_original
        expect(liker.has_shelby_avatar).to be_true
      end
    end

    it "returns stats on buckets found and updated" do
      expect(GT::VideoLikerManager.refresh_all_user_data).to eql({
        :buckets_found => 2,
        :buckets_updated => 2
      })
    end

    it "only processes as many buckets as specified by the limit parameter" do
      expect(GT::VideoLikerManager.refresh_all_user_data(:limit => 1)).to eql({
        :buckets_found => 1,
        :buckets_updated => 1
      })
    end

  end

end