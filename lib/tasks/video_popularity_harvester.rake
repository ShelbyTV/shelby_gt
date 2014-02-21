namespace :util do

  desc 'Harvest popular videos by some interval, defaults to week'
  task :harvest_popular_videos, [:interval] => :environment do |t, args|
    require 'video_popularity_harvester'

    interval = args.interval || 'week'

    opts = {
      :persist => true,
      :limit => 5000000,
      :interval => interval,
      :cutoff => 50,
      :videos_to_return => 20
    }

    p = GT::VideoPopularityHarvester.new(opts)
    p.aggregate
    p.incorporate_video_data
    p.save_video_aggregation

  end
end
