namespace :video_liker_utils do

  desc "Refresh user data for all video likers"
  task :refresh_video_likers, [:limit] => [:environment] do |t, args|
    require 'video_liker_manager'

    Rails.logger = Logger.new(STDOUT)

    args.with_defaults(:limit => "0")

    options = {
      :limit => args[:limit].to_i
    }

    Rails.logger.info("Refreshing video likers denormalized data from user models")
    result = GT::VideoLikerManager.refresh_all_user_data(options)
    Rails.logger.info("DONE!")
    Rails.logger.info("STATS:")
    Rails.logger.info(result)

  end

end
