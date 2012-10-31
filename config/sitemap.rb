# Set the host name for URL creation
SitemapGenerator::Sitemap.default_host = "http://shelby.tv"

# Set the host name for where the sitemap exists; okay to be different if pointed to by robots.txt on default_host
SitemapGenerator::Sitemap.sitemaps_host = "http://api.shelby.tv"

# Use a shared directory that stays constant across capistrano deploys on API server to hold sitemaps
SitemapGenerator::Sitemap.sitemaps_path = 'system/'


SitemapGenerator::Sitemap.create do

  Video.find_each.fields(:provider_name, :provider_id, :title) do |video|
    titleHyph = video.title ? video.title.downcase.gsub(/\W/,'-').gsub(/"/,"'").squeeze('-').chomp('-') : ""
    add("video/#{video.provider_name}/#{video.provider_id}/#{titleHyph}")
 
    # this keeps memory usage and object lookup speed at reasonable levels 
    MongoMapper::Plugins::IdentityMap.clear
  end

end

