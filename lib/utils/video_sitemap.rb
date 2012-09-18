###############################################################################
#
# Generate a video sitemap for SEO video pages
#
# Can be run in your environment via something like:
#
# rails runner -e development lib/utils/video_sitemap.rb 
#
#  - or -
#
# rails runner -e production lib/utils/video_sitemap.rb 
#
# TODO: need to automate running / deployment / search engine pinging
#
###############################################################################

require 'rubygems'
require 'bundler/setup'

require 'sitemap_generator'

def hyphenateString(title)
  title ? title.downcase.gsub(/\W/,'-').gsub(/"/,"'").squeeze('-').chomp('-') : ""
end

SitemapGenerator::Sitemap.default_host = 'http://shelby.tv'
SitemapGenerator::Sitemap.create do

  youtubeVideos = Video.where(:provider_name => "youtube").limit(10000)
  
  youtubeVideos.each do |youtubeVideo|
   
    titleHyph = hyphenateString(youtubeVideo.title)
    add("/video/youtube/#{youtubeVideo.provider_id}/#{titleHyph}", :video => {
      :thumbnail_loc => youtubeVideo.thumbnail_url,
      :title => youtubeVideo.title,
      :description => youtubeVideo.description,
      :player_loc => "http://www.youtube.com/v/#{youtubeVideo.provider_id}",
    })
    
  end if youtubeVideos  
  
end

