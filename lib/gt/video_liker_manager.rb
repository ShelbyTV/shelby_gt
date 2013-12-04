# This manager allows write access and read access to the Video Likers with familiar skip and limit semantics
# It should be used instead of direct MongoMapper access because the video liker information
# => is bucketed in the DB and this manager abstracts away the complexity of the bucketing calculations
module GT
  class VideoLikerManager
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
      get_partial_bucket = limit_bucket_values[:remainder] > 0
      bucket_limit = get_partial_bucket ? limit_bucket_values[:buckets] + 1 : limit_bucket_values[:buckets]

      buckets = VideoLikerBucket.where({
        :provider_name => video.provider_name,
        :provider_id => video.provider_id
        }).sort(:sequence).limit(bucket_limit).all

      likers = []
      buckets.each_with_index do |bucket, i|
        unless (i == bucket_limit - 1) && (get_partial_bucket)
          likers.concat bucket.likers
        else
          likers.concat bucket.likers.first(limit_bucket_values[:remainder])
        end
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