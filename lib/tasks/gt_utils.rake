namespace :utils do

  desc 'Tweet videos on behalf of a user from our sitemaps'
  task :tweet_video_from_sitemap => :environment do
    require 'sitemap_tweeter'

    u = User.find_by_nickname 'hermanoshelby'
    d = Dev::SitemapTweeter.new(u, 1, {'sleep_time' => 10, 'box' => 'api'})

    AdminMailer.sitemap_tweeter_summary.deliver

  end
end


