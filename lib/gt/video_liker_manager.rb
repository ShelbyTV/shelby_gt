# This manager allows write access and read access to the Video Likers with familiar skip and limit semantics
# It should be used instead of direct MongoMapper access because the video liker information
# => is bucketed in the DB and this manager abstracts away the complexity of the bucketing calculations
module GT
  class VideoLikerManager
    # Given a video and a user who is liking it, create and persist a VideoLiker document
    # NB: This does not update the liker_count in the local Video model - callers must
    #   call reload on the video model after this method to accomplish that
    # -- params --
    # video -- video for which to add a tracked liker
    # liker -- user who is liking the video
    def self.add_liker_for_video(video, liker)
      # atomically increment the video's liker count to reserve our bucket position
      new_video_document = Video.collection.find_and_modify({
        :query => {:_id => video.id},
        :update => {:$inc => {:y => 1}},
        :new => true
      })
      new_liker_count = new_video_document["y"]

      # create the new VideoLiker document
      video_liker = VideoLiker.new({
        :user => liker,
        :name => liker.name,
        :nickname => liker.nickname,
        :user_image => liker.user_image,
        :user_image_original => liker.user_image_original,
        :has_shelby_avatar => liker.has_shelby_avatar,
        :public_roll => liker.public_roll
      })

      # upsert a VideoLikerBucket and push this VideoLiker onto its array of likers
      bucket_sequence_no = self.calculate_bucket_values(new_liker_count - 1)[:buckets]

      VideoLikerBucket.collection.update({
        :a => video.provider_name,
        :b => video.provider_id,
        :c => bucket_sequence_no
      }, {
        :$push => {:likers => video_liker.to_mongo}
      }, {
        :upsert => true
      })

    end

    # Given a video, return all the VideoLikers associated with it
    # -- params --
    # video -- video for which to find likers
    #
    # -- options --
    # limit -- the maximum number of likers to return (default is the size of a single bucket)
    def self.get_likers_for_video(video, options={})
      defaults = {
          :limit => Settings::VideoLiker.bucket_size,
      }
      options = defaults.merge(options)
      limit = options.delete(:limit)

      limit_bucket_values = self.calculate_bucket_values(limit)
      bucket_limit = limit_bucket_values[:buckets] + 1

      buckets = VideoLikerBucket.where({
        :provider_name => video.provider_name,
        :provider_id => video.provider_id
        }).sort(:sequence.desc).limit(bucket_limit)

      likers = []
      buckets.each do |bucket|
        bucket_likers = bucket.likers.reverse
        likers_left = limit - likers.length
        unless bucket_likers.length > likers_left
          likers.concat bucket_likers
        else
          likers.concat bucket_likers.first(likers_left)
        end
        break if bucket_likers == limit
      end

      return likers
    end

    private

      def self.calculate_bucket_values(liker_count)
        res = {}
        res[:buckets] = liker_count / Settings::VideoLiker.bucket_size
        res[:remainder] = liker_count % Settings::VideoLiker.bucket_size
        return res
      end
  end
end