# Set the host name for URL creation
SitemapGenerator::Sitemap.default_host = "http://shelby.tv"

# Set the host name for where the sitemap exists; okay to be different if pointed to by robots.txt on default_host
SitemapGenerator::Sitemap.sitemaps_host = "http://api.shelby.tv"

# Use a shared directory that stays constant across capistrano deploys on API server to hold sitemaps
SitemapGenerator::Sitemap.sitemaps_path = 'system/'


SitemapGenerator::Sitemap.create do

  youtubeVideos = Video.where(:provider_name => "youtube").limit(10000)
  
  youtubeVideos.each do |youtubeVideo|
    if youtubeVideo.thumbnail_url   
      titleHyph = youtubeVideo.title ? youtubeVideo.title.downcase.gsub(/\W/,'-').gsub(/"/,"'").squeeze('-').chomp('-') : ""
      add("video/youtube/#{youtubeVideo.provider_id}/#{titleHyph}", :video => {
        :thumbnail_loc => youtubeVideo.thumbnail_url,
        :title => youtubeVideo.title,
        :description => youtubeVideo.description,
        :player_loc => "http://www.youtube.com/v/#{youtubeVideo.provider_id}",
      })
    end    
  end if youtubeVideos  
  
end

