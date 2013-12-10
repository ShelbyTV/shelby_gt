require 'spec_helper'
require 'video_liker_manager'

# UNIT test
describe GT::VideoLikerManager do

  before(:each) do
    @v = Factory.create(:video)
  end

  describe "add_liker_for_video" do

    before(:each) do
      @liker_public_roll = Factory.create(:roll)
      @liker = Factory.create(:user, :public_roll => @liker_public_roll)
      @video_liker = Factory.create(:video_liker, :user => @liker, :nickname => @liker.nickname, :has_shelby_avatar => @liker.has_shelby_avatar)
      @video_liker.stub(:to_mongo).and_return(@video_liker)
      @updated_video_document = {"y" => 1}
      Video.stub_chain(:collection, :find_and_modify).and_return(@updated_video_document)
      VideoLikerBucket.stub_chain(:collection, :update)
      VideoLikerBucket.stub_chain(:where, :sort, :first)
    end

    it "increments the video's number of likers" do
      video_collection = double("video_collection")
      Video.should_receive(:collection).and_return(video_collection)
      video_collection.should_receive(:find_and_modify).with({
        :query => {:_id => @v.id},
        :update => {:$inc => {:y => 1}},
        :new => true
      }).and_return(@updated_video_document)

      GT::VideoLikerManager.add_liker_for_video(@v, @liker)
    end

    it "doesn't do anything if the liker is already in the current bucket" do
      existing_video_liker_bucket = double("video_liker_bucket", :likers => [@video_liker])
      VideoLikerBucket.stub_chain(:where, :sort, :first).and_return(existing_video_liker_bucket)

      Video.should_not_receive(:collection)
      VideoLiker.should_not_receive(:new)
      VideoLikerBucket.should_not_receive(:collection)

      GT::VideoLikerManager.add_liker_for_video(@v, @liker)
    end

    context "add/update bucket" do

      before(:each) do
        @video_liker_bucket_collection = double("video_liker_bucket_collection")
        VideoLikerBucket.should_receive(:collection).and_return(@video_liker_bucket_collection)

        Settings::VideoLiker["bucket_size"] = 1
      end

      it "creates a VideoLiker document and upserts a bucket containing it" do
        VideoLiker.should_receive(:new).with({
          :user => @liker,
          :name => @liker.name,
          :nickname => @liker.nickname,
          :user_image => @liker.user_image,
          :user_image_original => @liker.user_image_original,
          :has_shelby_avatar => @liker.has_shelby_avatar,
          :public_roll => @liker_public_roll
        }).and_return(@video_liker)

        @video_liker_bucket_collection.should_receive(:update).with({
          :a => @v.provider_name,
          :b => @v.provider_id,
          :c => 0
        },{
          :$push => {:likers => @video_liker}
        },{
          :upsert => true
        })

        GT::VideoLikerManager.add_liker_for_video(@v, @liker)
      end

      it "upserts into the next bucket when there are already bucket_size likers in the first one" do
        VideoLiker.stub(:new).and_return(@video_liker)
        @updated_video_document["y"] = 2

        @video_liker_bucket_collection.should_receive(:update).with({
          :a => @v.provider_name,
          :b => @v.provider_id,
          :c => 1
        },{
          :$push => {:likers => @video_liker}
        },{
          :upsert => true
        })

        GT::VideoLikerManager.add_liker_for_video(@v, @liker)
      end

    end

  end

  describe "get_likers_for_video" do

    before(:each) do
      Settings::VideoLiker["bucket_size"] = 3

      where_query = double("where_query")
      @sort_query = double("sort_query")
      @limit_query = double("limit_query")

      VideoLikerBucket.should_receive(:where).with({:provider_name => @v.provider_name, :provider_id => @v.provider_id}).and_return(where_query)
      where_query.should_receive(:sort).with(:sequence.desc).and_return(@sort_query)
      @sort_query.stub(:limit).and_return(@limit_query)
      @limit_query.stub(:each)
    end

    it "fetches two buckets of likers by default" do
      @sort_query.should_receive(:limit).with(2).and_return(@limit_query)

      GT::VideoLikerManager.get_likers_for_video(@v)
    end

    it "fetches the correct number of buckets when a limit is specified and matches an exact number of buckets" do
      limit = Settings::VideoLiker.bucket_size * 2

      @sort_query.should_receive(:limit).with(3).and_return(@limit_query)

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

      @limit_query.should_receive(:each).and_yield(video_liker_bucket)

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

        each_expectation = @limit_query.should_receive(:each)
        @buckets.reverse.each do |bucket|
          each_expectation = each_expectation.and_yield(bucket)
        end
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
        expect(GT::VideoLikerManager.get_likers_for_video(@v, {:limit => 3})).to eql [@video_likers[-2], @video_likers[-3], @video_likers[-4]]
      end
    end

  end

end