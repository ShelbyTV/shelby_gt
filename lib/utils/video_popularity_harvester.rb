# encoding: UTF-8
module GT
  class VideoPopularityHarvester

    ######################
    #
    # A tool to harvest the most popular videos **as seen by Shelby
    #  over a given time period
    #
    #  Returns an array of video type objects with how many times a video has been shared
    #
    # @param [opt, Hash] Options including:
    #       [REQUIRED] interval: time frame to look at. should be a string: 'week' or 'day'
    #                         videos_to_return: how many videos to return after video aggregation
    #                         cutoff: threshold of frequency of shares
    #                         limit: how many Conversations are scanned
    #                         write:  should persist results to redis
    #
    #
    ######################

    def initialize(opts={})
      @redis_client = Redis.new(:port => Settings::Resque.redis_port) if opts[:write]
      @aggregation_limit = opts[:limit] ? opts[:limit] : 10000
      @video_count_cutoff = opts[:cutoff] ? opts[:cutoff] : 1000
      @videos_to_return = opts[:videos_to_return] ? opts[:videos_to_return] : 20

      # period to look over
      raise ArgumentError, "must include an interval to look back on, eg 'week' or 'day' " unless opts[:interval]
      if opts[:interval] == "week"
        @since_date = BSON::ObjectId.from_time(Time.now - 1.week)
        @to_date = BSON::ObjectId.from_time(Time.now)
      elsif opts[:interval] == "day"
        @since_date = BSON::ObjectId.from_time(Time.now - 1.day)
        @to_date = BSON::ObjectId.from_time(Time.now)
      else
        raise ArgumentError, "opts[:interval] should be a string, eg 'week' or 'day' "
      end
    end

    def aggregate
      @videos = Conversation.collection.aggregate([
          { '$match' => {
              '_id' => {
                  '$gte' => @since_date,
                  '$lt' => @to_date
              }
            }
          },
          {
            '$group' => {
                "_id" => "$a",
                "count" => {
                    "$sum" => 1
                }
            }
          },
          {
            "$limit" => @aggregation_limit
          },
          {
            "$sort" => {
                "count" => -1
            }
          },
          {
            "$match" => {
                'count' => {
                    "$gt" => @video_count_cutoff
                }
            }
          },
          {
            "$limit" => @videos_to_return
          },
          {
            "$project" => {
                "_id" => 0,
                "video_id" => '$_id',
                "count" => 1
            }
          }
      ],
      {
        :read => :secondary
      })

    end

    def incorporate_video_data(video_list)

      video_list.each do |v|
        if video = Video.find(v["video_id"])
          v["title"] = video.title
          v["description"] = video.description
          v["source_url"] = video.source_url
          v["embed_url"] = video.embed_url
          v["thumbnail_url"] = video.thumbnail_url
          v["duration"] = video.duration
        end
      end

    end

    def save_video_aggregation(video_list)
      return "NOT SET TO WRITE TO REDIS. TO DO SO, SET: opt[:write] = true" unless @redis_client

      video_list.each do |v|

        key = "#{Date.today.to_s}::#{@inverval}::#{v['video_id']}}"
        @redis_client.mapped_hmset(key, v)

      end

    end

  end
end
