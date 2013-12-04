require 'spec_helper'
require 'video_liker_manager'

# UNIT test
describe GT::VideoLikerManager do

  before(:each) do
    @v = Factory.create(:video)

    Settings::VideoLiker["bucket_size"] = 3

    where_query = double("where_query")
    @sort_query = double("sort_query")
    @limit_query = double("limit_query")

    VideoLikerBucket.should_receive(:where).with({:provider_name => @v.provider_name, :provider_id => @v.provider_id}).and_return(where_query)
    where_query.should_receive(:sort).with(:sequence).and_return(@sort_query)
    @sort_query.stub(:limit).and_return(@limit_query)
    @limit_query.stub(:all).and_return([])
  end

  it "fetches one bucket of likers by default" do
    @sort_query.should_receive(:limit).with(1).and_return(@limit_query)

    GT::VideoLikerManager.get_likers_for_video(@v)
  end

  it "fetches the correct number of buckets when a limit is specified and matches an exact number of buckets" do
    limit = Settings::VideoLiker.bucket_size * 2

    @sort_query.should_receive(:limit).with(2).and_return(@limit_query)

    GT::VideoLikerManager.get_likers_for_video(@v, {:limit => limit})
  end

  it "fetches the correct number of buckets when a limit is specified and doesn't match an exact number of buckets" do
    limit = (Settings::VideoLiker.bucket_size * 2) + 1

    @sort_query.should_receive(:limit).with(3).and_return(@limit_query)

    GT::VideoLikerManager.get_likers_for_video(@v, {:limit => limit})
  end

  it "iterates through the buckets and returns the likers" do
    liker = Factory.create(:user)
    video_liker = Factory.create(:video_liker, :nickname => liker.nickname, :has_shelby_avatar => false)
    video_liker_bucket = Factory.create(:video_liker_bucket)
    video_liker_bucket.likers << video_liker

    @limit_query.should_receive(:all).and_return([video_liker_bucket])

    expect(GT::VideoLikerManager.get_likers_for_video(@v)).to eql [video_liker]
  end

  context "multiple buckets" do
    before(:each) do
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
      end
    end

    it "returns the correct results for a limit midway through the first bucket" do
      @limit_query.should_receive(:all).and_return(@buckets.first(1))
      expect(GT::VideoLikerManager.get_likers_for_video(@v, {:limit => 2})).to eql [@video_likers[0], @video_likers[1]]
    end

    it "returns the correct results for a limit exactly containing the first bucket" do
      @limit_query.should_receive(:all).and_return(@buckets.first(1))
      expect(GT::VideoLikerManager.get_likers_for_video(@v, {:limit => 3})).to eql [@video_likers[0], @video_likers[1], @video_likers[2]]
    end

    it "returns the correct results for a limit midway through the second bucket" do
      @limit_query.should_receive(:all).and_return(@buckets.first(2))
      expect(GT::VideoLikerManager.get_likers_for_video(@v, {:limit => 5})).to eql [@video_likers[0], @video_likers[1], @video_likers[2], @video_likers[3], @video_likers[4]]
    end

    it "returns the correct results for a limit that exceeds the number of existing buckets" do
      @limit_query.should_receive(:all).and_return(@buckets)
      expect(GT::VideoLikerManager.get_likers_for_video(@v, {:limit => Settings::VideoLiker.bucket_size * 3})).to eql @video_likers
    end
  end

end